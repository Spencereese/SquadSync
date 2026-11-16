-- Proposed. Not applied. Needs Spencer's yes before it runs anywhere.
-- Does not grant anon or public. authenticated gets the new public wrappers only.
-- Existing rows stay: ready defaults to false, seat_target defaults to 8,
-- and status values already stored (open, locked, ended, cancelled) stay valid.
--
-- Lock rule (one rule): sq8.lock_spot_when_ready succeeds only when at least
-- one joiner has response = 'in' and every such joiner has ready = true.
-- The seat target is stored and shown. It is not the lock predicate.
-- Zero joiners, or any in-joiner who is not Ready, raises spot_not_ready.
-- A second lock of a call that is already locked returns without writing again.
--
-- Expiry uses the database clock. sq8.expire_open_spot sets status = 'expired'
-- when the call is still open, unlocked, unclosed, and now() >= join_until.
-- It does not delete RSVPs and does not remove starters. Reads go through
-- public.sq8_read_open_spot, which expires first and then returns the row,
-- so a read comes back with status expired. A plain select of the table does
-- not stamp expiry; the client uses the read RPC when it is present.
--
-- Join window, re-checked against 0013 sq8.rsvp_spot and left unchanged:
--   if answer = 'in' and now() >= join_until and not coalesce(is_starter, false)
--   then raise exception 'spot_join_closed'
-- A non-starter cannot join once the five-minute window has passed.
-- A starter already on the call can still answer 'in' after that. This file
-- does not replace sq8.rsvp_spot, sq8.call_spot, sq8.lock_spot, sq8.end_spot,
-- or sq8.cancel_spot.
--
-- Policies, re-checked against 0013. Both are table-level SELECT for
-- authenticated members. Neither lists columns, so seat_target and ready
-- are covered without rewriting them:
--   sq8_spot_calls_select_member
--     using (member of sq8_spot_calls.squad_id)
--   sq8_spot_rsvps_select_member
--     using (member of the call's squad)
-- There is no insert, update, or delete policy. Writes stay inside these
-- security definer functions, which is how 0013 already writes.
--
-- Triggers, re-checked: 0013 creates none on sq8_spot_calls or sq8_spot_rsvps.
-- Later files do not add one. 0017 says it does not alter sq8_spot_calls.
-- This file creates none. Realtime already publishes both tables, so the new
-- columns ride along. Lock order matches 0013: the squad row, then the call.
--
-- The new functions are volatile on purpose. A GET probe is refused and does
-- not run them. Do not mark them stable.

alter table public.sq8_spot_calls
  add column if not exists seat_target integer not null default 8;

alter table public.sq8_spot_calls
  drop constraint if exists sq8_spot_calls_seat_target;

alter table public.sq8_spot_calls
  add constraint sq8_spot_calls_seat_target
  check (seat_target >= 1 and seat_target <= 8);

alter table public.sq8_spot_rsvps
  add column if not exists ready boolean not null default false;

alter table public.sq8_spot_calls
  drop constraint if exists sq8_spot_calls_status;

alter table public.sq8_spot_calls
  add constraint sq8_spot_calls_status
  check (status in ('open', 'locked', 'ended', 'cancelled', 'expired'));

create or replace function sq8.expire_open_spot(target_call uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_status text;
  locked timestamptz;
  closed timestamptz;
  join_until timestamptz;
begin
  select calls.status, calls.locked_at, calls.closed_at, calls.join_until
    into current_status, locked, closed, join_until
  from public.sq8_spot_calls as calls
  where calls.id = target_call
  for update;

  if current_status is null then
    return null;
  end if;

  if current_status = 'open'
     and locked is null
     and closed is null
     and now() >= join_until then
    update public.sq8_spot_calls
    set status = 'expired'
    where id = target_call
      and status = 'open'
      and locked_at is null
      and closed_at is null;
    return 'expired';
  end if;

  return current_status;
end;
$$;

create or replace function sq8.set_spot_ready(target_call uuid, is_ready boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  locked timestamptz;
  closed timestamptz;
  current_status text;
  answer text;
begin
  if me is null then
    raise exception 'spot_signed_out' using errcode = '42501';
  end if;

  select calls.squad_id
    into squad
  from public.sq8_spot_calls as calls
  where calls.id = target_call;
  if squad is null then
    raise exception 'spot_missing' using errcode = 'P0001';
  end if;

  perform 1
  from public.sq8_squads
  where id = squad
  for update;

  select calls.locked_at, calls.closed_at, calls.status
    into locked, closed, current_status
  from public.sq8_spot_calls as calls
  where calls.id = target_call
  for update;

  if not exists (
    select 1
    from public.sq8_squad_members
    where squad_id = squad
      and user_id = me
  ) then
    raise exception 'spot_not_member' using errcode = '42501';
  end if;
  if closed is not null or current_status in ('ended', 'cancelled') then
    raise exception 'spot_closed' using errcode = 'P0001';
  end if;
  if locked is not null or current_status = 'locked' then
    raise exception 'spot_locked' using errcode = 'P0001';
  end if;
  -- A raise rolls the transaction back, so this does not stamp status.
  -- sq8.read_open_spot is what commits 'expired'.
  if current_status = 'expired' or (
    current_status = 'open' and exists (
      select 1
      from public.sq8_spot_calls as calls
      where calls.id = target_call
        and now() >= calls.join_until
    )
  ) then
    raise exception 'spot_expired' using errcode = 'P0001';
  end if;

  select rsvps.response
    into answer
  from public.sq8_spot_rsvps as rsvps
  where rsvps.call_id = target_call
    and rsvps.user_id = me
  for update;

  if answer is distinct from 'in' then
    raise exception 'spot_not_in' using errcode = 'P0001';
  end if;

  update public.sq8_spot_rsvps
  set ready = coalesce(is_ready, false),
      updated_at = now()
  where call_id = target_call
    and user_id = me;
end;
$$;

create or replace function sq8.lock_spot_when_ready(target_call uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  caller uuid;
  owner uuid;
  closed timestamptz;
  locked timestamptz;
  join_until timestamptz;
  current_status text;
  seated integer;
  ready_count integer;
begin
  if me is null then
    raise exception 'spot_signed_out' using errcode = '42501';
  end if;

  select calls.squad_id, calls.caller_id
    into squad, caller
  from public.sq8_spot_calls as calls
  where calls.id = target_call;
  if squad is null then
    raise exception 'spot_missing' using errcode = 'P0001';
  end if;

  perform 1
  from public.sq8_squads
  where id = squad
  for update;

  select calls.closed_at, calls.locked_at, calls.caller_id, squads.owner_id
    into closed, locked, caller, owner
  from public.sq8_spot_calls as calls
  join public.sq8_squads as squads
    on squads.id = calls.squad_id
  where calls.id = target_call
  for update;

  if me is distinct from caller and me is distinct from owner then
    raise exception 'spot_not_caller' using errcode = '42501';
  end if;
  if closed is not null then
    raise exception 'spot_closed' using errcode = 'P0001';
  end if;
  if locked is not null then
    return;
  end if;

  select calls.status, calls.join_until
    into current_status, join_until
  from public.sq8_spot_calls as calls
  where calls.id = target_call;

  -- Refuse without stamping. A raise would undo the stamp, and the read RPC
  -- is what commits status = 'expired' on the server clock.
  if current_status = 'expired' or now() >= join_until then
    raise exception 'spot_expired' using errcode = 'P0001';
  end if;
  if current_status is distinct from 'open' then
    raise exception 'spot_closed' using errcode = 'P0001';
  end if;

  select count(*) filter (where rsvps.response = 'in'),
         count(*) filter (where rsvps.response = 'in' and rsvps.ready)
    into seated, ready_count
  from public.sq8_spot_rsvps as rsvps
  where rsvps.call_id = target_call;

  if coalesce(seated, 0) < 1 or coalesce(ready_count, 0) < coalesce(seated, 0) then
    raise exception 'spot_not_ready' using errcode = 'P0001';
  end if;

  update public.sq8_spot_calls
  set locked_at = coalesce(sq8_spot_calls.locked_at, now()),
      locked_by = coalesce(sq8_spot_calls.locked_by, me),
      status = 'locked'
  where id = target_call
    and locked_at is null;
end;
$$;

create or replace function sq8.read_open_spot(squad uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  found uuid;
begin
  if me is null then
    raise exception 'spot_signed_out' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.sq8_squad_members
    where squad_id = squad
      and user_id = me
  ) then
    raise exception 'spot_not_member' using errcode = '42501';
  end if;

  perform 1
  from public.sq8_squads
  where id = squad
  for update;

  select calls.id
    into found
  from public.sq8_spot_calls as calls
  where calls.squad_id = squad
    and calls.closed_at is null
  order by calls.called_at desc
  limit 1
  for update;

  if found is null then
    return jsonb_build_object('call', null, 'rsvps', '[]'::jsonb);
  end if;

  perform sq8.expire_open_spot(found);

  return (
    select jsonb_build_object(
      'call', jsonb_build_object(
        'id', calls.id,
        'squad_id', calls.squad_id,
        'caller_id', calls.caller_id,
        'game', calls.game,
        'called_at', calls.called_at,
        'join_until', calls.join_until,
        'locked_at', calls.locked_at,
        'closed_at', calls.closed_at,
        'status', calls.status,
        'seat_target', calls.seat_target
      ),
      'rsvps', coalesce((
        select jsonb_agg(jsonb_build_object(
          'user_id', rsvps.user_id,
          'response', rsvps.response,
          'starter', rsvps.starter,
          'ready', rsvps.ready
        ))
        from public.sq8_spot_rsvps as rsvps
        where rsvps.call_id = calls.id
      ), '[]'::jsonb)
    )
    from public.sq8_spot_calls as calls
    where calls.id = found
  );
end;
$$;

revoke all on function sq8.expire_open_spot(uuid) from public, anon, authenticated;
revoke all on function sq8.set_spot_ready(uuid, boolean) from public, anon, authenticated;
revoke all on function sq8.lock_spot_when_ready(uuid) from public, anon, authenticated;
revoke all on function sq8.read_open_spot(uuid) from public, anon, authenticated;

create or replace function public.sq8_set_spot_ready(call_id uuid, ready boolean)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.set_spot_ready(call_id, ready);
$$;

create or replace function public.sq8_lock_spot_when_ready(call_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.lock_spot_when_ready(call_id);
$$;

create or replace function public.sq8_read_open_spot(squad uuid)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.read_open_spot(squad);
$$;

revoke all on function public.sq8_set_spot_ready(uuid, boolean) from public, anon;
revoke all on function public.sq8_lock_spot_when_ready(uuid) from public, anon;
revoke all on function public.sq8_read_open_spot(uuid) from public, anon;
grant execute on function public.sq8_set_spot_ready(uuid, boolean) to authenticated;
grant execute on function public.sq8_lock_spot_when_ready(uuid) to authenticated;
grant execute on function public.sq8_read_open_spot(uuid) to authenticated;

-- down
-- update public.sq8_spot_calls
-- set status = 'open'
-- where status = 'expired'
--   and locked_at is null
--   and closed_at is null;
-- alter table public.sq8_spot_calls drop constraint if exists sq8_spot_calls_status;
-- alter table public.sq8_spot_calls
--   add constraint sq8_spot_calls_status
--   check (status in ('open', 'locked', 'ended', 'cancelled'));
-- alter table public.sq8_spot_calls drop constraint if exists sq8_spot_calls_seat_target;
-- alter table public.sq8_spot_calls drop column if exists seat_target;
-- alter table public.sq8_spot_rsvps drop column if exists ready;
-- drop function if exists public.sq8_read_open_spot(uuid);
-- drop function if exists public.sq8_lock_spot_when_ready(uuid);
-- drop function if exists public.sq8_set_spot_ready(uuid, boolean);
-- drop function if exists sq8.read_open_spot(uuid);
-- drop function if exists sq8.lock_spot_when_ready(uuid);
-- drop function if exists sq8.set_spot_ready(uuid, boolean);
-- drop function if exists sq8.expire_open_spot(uuid);
-- 0013 sq8.lock_spot, sq8.rsvp_spot, and both select policies were not replaced.
