-- Proposed. Not applied to the live project.
-- One live spot call per squad. The join window is five minutes on the
-- database clock. Starters stay able to be in after that window. A starter
-- is available now, or available later whose until_at has arrived and is
-- still inside the following 60 minutes. That matches the phone, which
-- promotes a later row for an hour and does not rewrite the stored kind.
-- until_at on an available_later row is the instant they asked to become
-- available.
-- The caller can cancel before lock. The caller or the owner can end a
-- locked call. A locked call also ends lazily when the next call finds it
-- more than 6 hours past locked_at. An unlocked call past join_until is
-- closed the same way, when someone calls the next spot.
-- Lock order matches file 11: the squad row, then the call, then its RSVPs.
-- Deleting a squad locks the squad and then, through the cascade, the call.
-- Realtime DELETE payloads carry the primary key only (id, or call_id and
-- user_id). They are not filtered by squad_id.
-- Does not grant anon or public. authenticated gets the public wrappers only.

create table if not exists public.sq8_spot_calls (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  caller_id uuid not null references public.sq8_profiles (id),
  game text not null,
  starts_at timestamptz not null,
  called_at timestamptz not null default now(),
  join_until timestamptz not null,
  locked_at timestamptz,
  locked_by uuid references public.sq8_profiles (id),
  closed_at timestamptz,
  status text not null default 'open',
  constraint sq8_spot_calls_game_not_blank
    check (char_length(btrim(game)) > 0),
  constraint sq8_spot_calls_status
    check (status in ('open', 'locked', 'ended', 'cancelled'))
);

alter table public.sq8_spot_calls
  add column if not exists status text;

update public.sq8_spot_calls
set status = case
  when closed_at is not null then 'ended'
  when locked_at is not null then 'locked'
  else 'open'
end
where status is null;

alter table public.sq8_spot_calls
  alter column status set default 'open';

alter table public.sq8_spot_calls
  alter column status set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'sq8_spot_calls_status'
      and conrelid = 'public.sq8_spot_calls'::regclass
  ) then
    alter table public.sq8_spot_calls
      add constraint sq8_spot_calls_status
      check (status in ('open', 'locked', 'ended', 'cancelled'));
  end if;
end $$;

create unique index if not exists sq8_spot_calls_one_live
  on public.sq8_spot_calls (squad_id)
  where closed_at is null;

create index if not exists sq8_spot_calls_squad
  on public.sq8_spot_calls (squad_id, called_at desc);

create table if not exists public.sq8_spot_rsvps (
  call_id uuid not null references public.sq8_spot_calls (id) on delete cascade,
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  response text not null,
  starter boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (call_id, user_id),
  constraint sq8_spot_rsvps_response
    check (response in ('in', 'out'))
);

alter table public.sq8_spot_calls enable row level security;
alter table public.sq8_spot_calls force row level security;
alter table public.sq8_spot_rsvps enable row level security;
alter table public.sq8_spot_rsvps force row level security;

revoke all on public.sq8_spot_calls from public, anon;
revoke all on public.sq8_spot_rsvps from public, anon;
grant select on public.sq8_spot_calls to authenticated;
grant select on public.sq8_spot_rsvps to authenticated;

drop policy if exists sq8_spot_calls_select_member on public.sq8_spot_calls;
create policy sq8_spot_calls_select_member
  on public.sq8_spot_calls
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.sq8_squad_members as members
      where members.squad_id = sq8_spot_calls.squad_id
        and members.user_id = (select auth.uid())
    )
  );

drop policy if exists sq8_spot_rsvps_select_member on public.sq8_spot_rsvps;
create policy sq8_spot_rsvps_select_member
  on public.sq8_spot_rsvps
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.sq8_spot_calls as calls
      join public.sq8_squad_members as members
        on members.squad_id = calls.squad_id
      where calls.id = sq8_spot_rsvps.call_id
        and members.user_id = (select auth.uid())
    )
  );

create or replace function sq8.call_spot(
  squad uuid,
  game text,
  starts_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  live_id uuid;
  live_locked timestamptz;
  live_until timestamptz;
  created uuid;
  label text := btrim(game);
  start_at timestamptz := coalesce(starts_at, now());
begin
  if me is null then
    raise exception 'spot_signed_out' using errcode = '42501';
  end if;
  if label is null or char_length(label) = 0 then
    raise exception 'spot_game_blank' using errcode = '22023';
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

  select calls.id, calls.locked_at, calls.join_until
    into live_id, live_locked, live_until
  from public.sq8_spot_calls as calls
  where calls.squad_id = squad
    and calls.closed_at is null
  for update;

  if live_id is not null
     and live_locked is not null
     and live_locked > now() - interval '6 hours' then
    raise exception 'spot_already_open' using errcode = 'P0001';
  end if;
  if live_id is not null and live_locked is null and live_until > now() then
    raise exception 'spot_already_open' using errcode = 'P0001';
  end if;
  if live_id is not null then
    update public.sq8_spot_calls
    set closed_at = now(),
        status = 'ended'
    where id = live_id;
  end if;

  insert into public.sq8_spot_calls (
    squad_id, caller_id, game, starts_at, called_at, join_until, status
  )
  values (
    squad, me, label, start_at, now(), now() + interval '5 minutes', 'open'
  )
  returning id into created;

  insert into public.sq8_spot_rsvps (call_id, user_id, response, starter)
  select created, members.user_id, 'in', true
  from public.sq8_squad_members as members
  join public.sq8_check_ins as check_ins
    on check_ins.user_id = members.user_id
   and check_ins.squad_id = members.squad_id
  where members.squad_id = squad
    and (
      (
        check_ins.kind = 'available_now'
        and check_ins.until_at > now()
      )
      or (
        check_ins.kind = 'available_later'
        and check_ins.until_at <= now()
        and check_ins.until_at + interval '60 minutes' > now()
      )
    );

  insert into public.sq8_spot_rsvps (call_id, user_id, response, starter)
  values (created, me, 'in', false)
  on conflict (call_id, user_id) do nothing;

  return created;
end;
$$;

create or replace function sq8.rsvp_spot(target_call uuid, spot_response text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  join_until timestamptz;
  locked timestamptz;
  closed timestamptz;
  answer text := btrim(spot_response);
  already text;
  is_starter boolean := false;
  seats integer;
begin
  if me is null then
    raise exception 'spot_signed_out' using errcode = '42501';
  end if;
  if answer is null or answer not in ('in', 'out') then
    raise exception 'spot_response' using errcode = '22023';
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

  select calls.join_until, calls.locked_at, calls.closed_at
    into join_until, locked, closed
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
  if closed is not null then
    raise exception 'spot_closed' using errcode = 'P0001';
  end if;
  if locked is not null then
    raise exception 'spot_locked' using errcode = 'P0001';
  end if;

  select rsvps.response, rsvps.starter
    into already, is_starter
  from public.sq8_spot_rsvps as rsvps
  where rsvps.call_id = target_call
    and rsvps.user_id = me;

  if answer = 'in' and now() >= join_until and not coalesce(is_starter, false) then
    raise exception 'spot_join_closed' using errcode = 'P0001';
  end if;
  if answer = 'in' and already is distinct from 'in' then
    select count(*)
      into seats
    from public.sq8_spot_rsvps as rsvps
    where rsvps.call_id = target_call
      and rsvps.response = 'in';
    if seats >= 8 then
      raise exception 'spot_full' using errcode = 'P0001';
    end if;
  end if;

  insert into public.sq8_spot_rsvps as rsvps (
    call_id, user_id, response, starter, updated_at
  )
  values (target_call, me, answer, coalesce(is_starter, false), now())
  on conflict (call_id, user_id) do update
    set response = excluded.response,
        updated_at = now();
end;
$$;

create or replace function sq8.lock_spot(target_call uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  caller uuid;
  owner uuid;
  closed timestamptz;
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

  select calls.closed_at, calls.caller_id, squads.owner_id
    into closed, caller, owner
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

  update public.sq8_spot_calls
  set locked_at = coalesce(sq8_spot_calls.locked_at, now()),
      locked_by = coalesce(sq8_spot_calls.locked_by, me),
      status = 'locked'
  where id = target_call;
end;
$$;

create or replace function sq8.end_spot(target_call uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  caller uuid;
  owner uuid;
  locked timestamptz;
  closed timestamptz;
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

  select calls.caller_id, calls.locked_at, calls.closed_at, squads.owner_id
    into caller, locked, closed, owner
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
  if locked is null then
    raise exception 'spot_not_locked' using errcode = 'P0001';
  end if;

  update public.sq8_spot_calls
  set closed_at = now(),
      status = 'ended'
  where id = target_call;
end;
$$;

create or replace function sq8.cancel_spot(target_call uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  caller uuid;
  locked timestamptz;
  closed timestamptz;
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

  select calls.caller_id, calls.locked_at, calls.closed_at
    into caller, locked, closed
  from public.sq8_spot_calls as calls
  where calls.id = target_call
  for update;

  if me is distinct from caller then
    raise exception 'spot_not_caller' using errcode = '42501';
  end if;
  if closed is not null then
    raise exception 'spot_closed' using errcode = 'P0001';
  end if;
  if locked is not null then
    raise exception 'spot_locked' using errcode = 'P0001';
  end if;

  update public.sq8_spot_calls
  set closed_at = now(),
      status = 'cancelled'
  where id = target_call;
end;
$$;

revoke all on function sq8.call_spot(uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function sq8.rsvp_spot(uuid, text) from public, anon, authenticated;
revoke all on function sq8.lock_spot(uuid) from public, anon, authenticated;
revoke all on function sq8.end_spot(uuid) from public, anon, authenticated;
revoke all on function sq8.cancel_spot(uuid) from public, anon, authenticated;

create or replace function public.sq8_call_spot(
  squad uuid,
  game text,
  starts_at timestamptz
)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select sq8.call_spot(squad, game, starts_at);
$$;

create or replace function public.sq8_rsvp_spot(call_id uuid, response text)
returns void
language sql
security definer
set search_path = ''
as $$
  select sq8.rsvp_spot(call_id, response);
$$;

create or replace function public.sq8_lock_spot(call_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select sq8.lock_spot(call_id);
$$;

create or replace function public.sq8_end_spot(call_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select sq8.end_spot(call_id);
$$;

create or replace function public.sq8_cancel_spot(call_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select sq8.cancel_spot(call_id);
$$;

revoke all on function public.sq8_call_spot(uuid, text, timestamptz) from public, anon;
revoke all on function public.sq8_rsvp_spot(uuid, text) from public, anon;
revoke all on function public.sq8_lock_spot(uuid) from public, anon;
revoke all on function public.sq8_end_spot(uuid) from public, anon;
revoke all on function public.sq8_cancel_spot(uuid) from public, anon;
grant execute on function public.sq8_call_spot(uuid, text, timestamptz) to authenticated;
grant execute on function public.sq8_rsvp_spot(uuid, text) to authenticated;
grant execute on function public.sq8_lock_spot(uuid) to authenticated;
grant execute on function public.sq8_end_spot(uuid) to authenticated;
grant execute on function public.sq8_cancel_spot(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['sq8_spot_calls', 'sq8_spot_rsvps']
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end $$;
