-- NOT applied live. Needs Spencer's yes before it runs on sfckxrnoiwetmzdycqaa.
-- Apply after 0013, 0020 and 0027. Additive and safe to run again.
--
-- "Game on": any member says what they're playing and how many more they
-- need ("Warzone, need 1"). It reuses sq8_spot_calls / sq8_spot_rsvps instead
-- of new tables:
--   kind         'game_on' (new column; old rows and old clients stay 'spot')
--   seat_target  starter plus the players needed (need 1 -> 2 seats), 2..8
--   join_until   the idle deadline: 3 hours after the last start, join,
--                leave or Ready. Joining is open until the seats fill; there
--                is no five-minute window and no lock step.
--   status       'open' while live; 'ended' when the starter closes it or the
--                last player leaves; 'expired' after 3 hours idle.
--
-- Rules, all on the database clock, all under the squad row lock (the same
-- lock order as 0013/0020: squad, then call, then its RSVPs):
--   * At most 2 open Game ons per group. Idle and empty ones are closed
--     first (sq8.sweep_game_ons), so a stale card never blocks a new one.
--   * Joining stops when the people in (who are still members) reach the
--     seat target: game_on_full.
--   * Only the starter can close it. The owner has no extra power here.
--   * Everyone leaving closes it.
--
-- Old app builds keep working on spot calls: the one-live unique index now
-- covers kind = 'spot' only, and 0013/0020 functions are not replaced. An old
-- build reading sq8_read_open_spot can see a Game on as a spot call; its
-- join_until is the idle deadline, so its expiry matches.
--
-- Writes only through these security definer functions; authenticated gets
-- the public wrappers. Reads stay on the 0013 select policies (members only).
-- Push: public.sq8_game_on_push_context is for the service role only (the
-- sq8-notify-message function), never authenticated.
-- Nothing is granted to anon or public.
-- Local check: supabase/tests/sq8_game_on.sql and sq8_game_on_race.sh.

alter table public.sq8_spot_calls
  add column if not exists kind text not null default 'spot';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'sq8_spot_calls_kind'
      and conrelid = 'public.sq8_spot_calls'::regclass
  ) then
    alter table public.sq8_spot_calls
      add constraint sq8_spot_calls_kind check (kind in ('spot', 'game_on'));
  end if;
end $$;

-- One live spot call per group, as before; Game ons are capped by the function.
create unique index if not exists sq8_spot_calls_one_live_spot
  on public.sq8_spot_calls (squad_id)
  where closed_at is null and kind = 'spot';
drop index if exists public.sq8_spot_calls_one_live;

create index if not exists sq8_spot_calls_game_on_open
  on public.sq8_spot_calls (squad_id, called_at)
  where kind = 'game_on' and closed_at is null;

-- Closes the group's idle (past join_until), already-finished and empty
-- (nobody in who is still a member) Game ons. Call with the squad row locked.
create or replace function sq8.sweep_game_ons(squad uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  update public.sq8_spot_calls as calls
  set status = case when calls.status in ('ended', 'cancelled') then calls.status else 'expired' end,
      closed_at = now()
  where calls.squad_id = squad
    and calls.kind = 'game_on'
    and calls.closed_at is null
    and (now() >= calls.join_until or calls.status in ('expired', 'ended', 'cancelled'));

  update public.sq8_spot_calls as calls
  set status = 'ended',
      closed_at = now()
  where calls.squad_id = squad
    and calls.kind = 'game_on'
    and calls.closed_at is null
    and not exists (
      select 1
      from public.sq8_spot_rsvps as rsvps
      join public.sq8_squad_members as members
        on members.squad_id = calls.squad_id
       and members.user_id = rsvps.user_id
      where rsvps.call_id = calls.id
        and rsvps.response = 'in'
    );
end;
$$;

create or replace function sq8.start_game_on(squad uuid, game text, need integer)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  label text := btrim(coalesce(game, ''));
  open_count integer;
  created uuid;
begin
  if me is null then
    raise exception 'game_on_signed_out' using errcode = '42501';
  end if;
  if char_length(label) = 0 then
    raise exception 'game_on_game_blank' using errcode = '22023';
  end if;
  if char_length(label) > 60 then
    raise exception 'game_on_game_long' using errcode = '22023';
  end if;
  if need is null or need < 1 or need > 7 then
    raise exception 'game_on_need_range' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.sq8_squad_members
    where squad_id = squad and user_id = me
  ) then
    raise exception 'game_on_not_member' using errcode = '42501';
  end if;

  perform 1 from public.sq8_squads where id = squad for update;

  perform sq8.sweep_game_ons(squad);

  select count(*) into open_count
  from public.sq8_spot_calls as calls
  where calls.squad_id = squad
    and calls.kind = 'game_on'
    and calls.closed_at is null;
  if open_count >= 2 then
    raise exception 'game_on_cap' using errcode = 'P0001';
  end if;

  insert into public.sq8_spot_calls (
    squad_id, caller_id, game, starts_at, called_at, join_until, status, seat_target, kind
  )
  values (
    squad, me, label, now(), now(), now() + interval '3 hours', 'open', need + 1, 'game_on'
  )
  returning id into created;

  insert into public.sq8_spot_rsvps (call_id, user_id, response, starter, ready, updated_at)
  values (created, me, 'in', true, false, now());

  return created;
end;
$$;

-- Locks the call's squad, then the call; sweeps; returns the call's state.
create or replace function sq8.lock_game_on(target_call uuid, out squad uuid, out caller uuid, out seats integer, out closed timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'game_on_signed_out' using errcode = '42501';
  end if;
  select calls.squad_id into squad
  from public.sq8_spot_calls as calls
  where calls.id = target_call and calls.kind = 'game_on';
  if squad is null then
    raise exception 'game_on_missing' using errcode = 'P0001';
  end if;

  perform 1 from public.sq8_squads where id = squad for update;

  if not exists (
    select 1 from public.sq8_squad_members
    where squad_id = squad and user_id = me
  ) then
    raise exception 'game_on_not_member' using errcode = '42501';
  end if;

  perform 1 from public.sq8_spot_calls where id = target_call for update;
  perform sq8.sweep_game_ons(squad);

  select calls.caller_id, calls.seat_target, calls.closed_at
    into caller, seats, closed
  from public.sq8_spot_calls as calls
  where calls.id = target_call;
end;
$$;

create or replace function sq8.join_game_on(target_call uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  state record;
  answer text;
  filled integer;
begin
  select * into state from sq8.lock_game_on(target_call);
  if state.closed is not null then
    raise exception 'game_on_closed' using errcode = 'P0001';
  end if;

  select rsvps.response into answer
  from public.sq8_spot_rsvps as rsvps
  where rsvps.call_id = target_call and rsvps.user_id = me
  for update;

  if answer is distinct from 'in' then
    select count(*) into filled
    from public.sq8_spot_rsvps as rsvps
    join public.sq8_squad_members as members
      on members.squad_id = state.squad
     and members.user_id = rsvps.user_id
    where rsvps.call_id = target_call
      and rsvps.response = 'in';
    if filled >= state.seats then
      raise exception 'game_on_full' using errcode = 'P0001';
    end if;

    insert into public.sq8_spot_rsvps (call_id, user_id, response, starter, ready, updated_at)
    values (target_call, me, 'in', false, false, now())
    on conflict (call_id, user_id) do update
      set response = 'in', updated_at = now();
  end if;

  update public.sq8_spot_calls
  set join_until = now() + interval '3 hours'
  where id = target_call;
end;
$$;

create or replace function sq8.leave_game_on(target_call uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  state record;
begin
  select * into state from sq8.lock_game_on(target_call);
  if state.closed is not null then
    return;
  end if;

  update public.sq8_spot_rsvps
  set response = 'out', updated_at = now()
  where call_id = target_call and user_id = me and response = 'in';

  if exists (
    select 1
    from public.sq8_spot_rsvps as rsvps
    join public.sq8_squad_members as members
      on members.squad_id = state.squad
     and members.user_id = rsvps.user_id
    where rsvps.call_id = target_call and rsvps.response = 'in'
  ) then
    update public.sq8_spot_calls
    set join_until = now() + interval '3 hours'
    where id = target_call;
  else
    update public.sq8_spot_calls
    set status = 'ended', closed_at = now()
    where id = target_call;
  end if;
end;
$$;

create or replace function sq8.set_game_on_ready(target_call uuid, is_ready boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  state record;
begin
  select * into state from sq8.lock_game_on(target_call);
  if state.closed is not null then
    raise exception 'game_on_closed' using errcode = 'P0001';
  end if;

  update public.sq8_spot_rsvps
  set ready = coalesce(is_ready, false), updated_at = now()
  where call_id = target_call and user_id = me and response = 'in';
  if not found then
    raise exception 'game_on_not_in' using errcode = 'P0001';
  end if;

  update public.sq8_spot_calls
  set join_until = now() + interval '3 hours'
  where id = target_call;
end;
$$;

create or replace function sq8.close_game_on(target_call uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  state record;
begin
  select * into state from sq8.lock_game_on(target_call);
  if state.caller is distinct from me then
    raise exception 'game_on_not_starter' using errcode = '42501';
  end if;
  if state.closed is not null then
    return;
  end if;
  update public.sq8_spot_calls
  set status = 'ended', closed_at = now()
  where id = target_call;
end;
$$;

-- Service role only: what the push says. Nothing about tokens.
create or replace function sq8.game_on_push_context(target_call uuid)
returns table (squad_id uuid, caller_id uuid, caller_name text, game text, need integer, kind text)
language sql
stable
security definer
set search_path = ''
as $$
  select calls.squad_id,
         calls.caller_id,
         profiles.display_name,
         calls.game,
         greatest(calls.seat_target - (
           select count(*)::integer from public.sq8_spot_rsvps as rsvps
           where rsvps.call_id = calls.id and rsvps.response = 'in'
         ), 0),
         calls.kind
  from public.sq8_spot_calls as calls
  left join public.sq8_profiles as profiles on profiles.id = calls.caller_id
  where calls.id = target_call;
$$;

revoke all on function sq8.sweep_game_ons(uuid) from public, anon, authenticated;
revoke all on function sq8.start_game_on(uuid, text, integer) from public, anon, authenticated;
revoke all on function sq8.lock_game_on(uuid) from public, anon, authenticated;
revoke all on function sq8.join_game_on(uuid) from public, anon, authenticated;
revoke all on function sq8.leave_game_on(uuid) from public, anon, authenticated;
revoke all on function sq8.set_game_on_ready(uuid, boolean) from public, anon, authenticated;
revoke all on function sq8.close_game_on(uuid) from public, anon, authenticated;
revoke all on function sq8.game_on_push_context(uuid) from public, anon, authenticated;

create or replace function public.sq8_start_game_on(squad uuid, game text, need integer)
returns uuid
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.start_game_on(squad, game, need);
$$;

create or replace function public.sq8_join_game_on(call_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.join_game_on(call_id);
$$;

create or replace function public.sq8_leave_game_on(call_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.leave_game_on(call_id);
$$;

create or replace function public.sq8_set_game_on_ready(call_id uuid, ready boolean)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.set_game_on_ready(call_id, ready);
$$;

create or replace function public.sq8_close_game_on(call_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.close_game_on(call_id);
$$;

create or replace function public.sq8_game_on_push_context(call_id uuid)
returns table (squad_id uuid, caller_id uuid, caller_name text, game text, need integer, kind text)
language sql
stable
security definer
set search_path = ''
as $$
  select * from sq8.game_on_push_context(call_id);
$$;

revoke all on function public.sq8_start_game_on(uuid, text, integer) from public, anon;
revoke all on function public.sq8_join_game_on(uuid) from public, anon;
revoke all on function public.sq8_leave_game_on(uuid) from public, anon;
revoke all on function public.sq8_set_game_on_ready(uuid, boolean) from public, anon;
revoke all on function public.sq8_close_game_on(uuid) from public, anon;
revoke all on function public.sq8_game_on_push_context(uuid) from public, anon, authenticated;
grant execute on function public.sq8_start_game_on(uuid, text, integer) to authenticated;
grant execute on function public.sq8_join_game_on(uuid) to authenticated;
grant execute on function public.sq8_leave_game_on(uuid) to authenticated;
grant execute on function public.sq8_set_game_on_ready(uuid, boolean) to authenticated;
grant execute on function public.sq8_close_game_on(uuid) to authenticated;

-- down
-- drop function if exists public.sq8_game_on_push_context(uuid);
-- drop function if exists public.sq8_close_game_on(uuid);
-- drop function if exists public.sq8_set_game_on_ready(uuid, boolean);
-- drop function if exists public.sq8_leave_game_on(uuid);
-- drop function if exists public.sq8_join_game_on(uuid);
-- drop function if exists public.sq8_start_game_on(uuid, text, integer);
-- drop function if exists sq8.game_on_push_context(uuid);
-- drop function if exists sq8.close_game_on(uuid);
-- drop function if exists sq8.set_game_on_ready(uuid, boolean);
-- drop function if exists sq8.leave_game_on(uuid);
-- drop function if exists sq8.join_game_on(uuid);
-- drop function if exists sq8.lock_game_on(uuid);
-- drop function if exists sq8.start_game_on(uuid, text, integer);
-- drop function if exists sq8.sweep_game_ons(uuid);
-- Close every Game on first, then put the one-live index back:
-- update public.sq8_spot_calls set status = 'ended', closed_at = now() where kind = 'game_on' and closed_at is null;
-- create unique index if not exists sq8_spot_calls_one_live on public.sq8_spot_calls (squad_id) where closed_at is null;
-- drop index if exists public.sq8_spot_calls_one_live_spot;
-- drop index if exists public.sq8_spot_calls_game_on_open;
-- alter table public.sq8_spot_calls drop constraint if exists sq8_spot_calls_kind;
-- alter table public.sq8_spot_calls drop column if exists kind;
