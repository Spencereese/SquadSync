-- Proposed. Not applied to the live project.
-- A scheduled session for one squad. Members can read. The creator or the
-- owner can change or cancel it. An RSVP is only the signed-in person's
-- own row, and at most eight people can be in. anon and public get nothing.
-- Realtime DELETE payloads for an RSVP carry the primary key only.
-- Running this file again is safe.

create table if not exists public.sq8_sessions (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  creator_id uuid not null references public.sq8_profiles (id),
  game text not null,
  starts_at timestamptz not null,
  duration_minutes integer,
  note text,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  constraint sq8_sessions_game_not_blank
    check (char_length(btrim(game)) > 0),
  constraint sq8_sessions_duration
    check (
      duration_minutes is null
      or (duration_minutes >= 15 and duration_minutes <= 1440)
    ),
  constraint sq8_sessions_note
    check (note is null or char_length(note) <= 280)
);

create index if not exists sq8_sessions_squad
  on public.sq8_sessions (squad_id, starts_at);

create table if not exists public.sq8_session_rsvps (
  session_id uuid not null references public.sq8_sessions (id) on delete cascade,
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  response text not null,
  updated_at timestamptz not null default now(),
  primary key (session_id, user_id),
  constraint sq8_session_rsvps_response
    check (response in ('in', 'maybe', 'out'))
);

alter table public.sq8_sessions enable row level security;
alter table public.sq8_sessions force row level security;
alter table public.sq8_session_rsvps enable row level security;
alter table public.sq8_session_rsvps force row level security;

revoke all on public.sq8_sessions from public, anon;
revoke all on public.sq8_session_rsvps from public, anon;
grant select, insert, update on public.sq8_sessions to authenticated;
grant select, insert, update, delete on public.sq8_session_rsvps to authenticated;

drop policy if exists sq8_sessions_select on public.sq8_sessions;
create policy sq8_sessions_select
  on public.sq8_sessions
  for select
  to authenticated
  using (sq8.is_member(squad_id));

drop policy if exists sq8_sessions_insert on public.sq8_sessions;
create policy sq8_sessions_insert
  on public.sq8_sessions
  for insert
  to authenticated
  with check (
    creator_id = (select auth.uid())
    and sq8.is_member(squad_id)
  );

drop policy if exists sq8_sessions_update on public.sq8_sessions;
create policy sq8_sessions_update
  on public.sq8_sessions
  for update
  to authenticated
  using (
    sq8.is_member(squad_id)
    and (
      creator_id = (select auth.uid())
      or exists (
        select 1
        from public.sq8_squads as squads
        where squads.id = squad_id
          and squads.owner_id = (select auth.uid())
      )
    )
  )
  with check (
    sq8.is_member(squad_id)
    and (
      creator_id = (select auth.uid())
      or exists (
        select 1
        from public.sq8_squads as squads
        where squads.id = squad_id
          and squads.owner_id = (select auth.uid())
      )
    )
  );

drop policy if exists sq8_session_rsvps_select on public.sq8_session_rsvps;
create policy sq8_session_rsvps_select
  on public.sq8_session_rsvps
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.sq8_sessions as sessions
      where sessions.id = session_id
        and sq8.is_member(sessions.squad_id)
    )
  );

drop policy if exists sq8_session_rsvps_insert on public.sq8_session_rsvps;
create policy sq8_session_rsvps_insert
  on public.sq8_session_rsvps
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.sq8_sessions as sessions
      where sessions.id = session_id
        and sessions.cancelled_at is null
        and sq8.is_member(sessions.squad_id)
    )
  );

drop policy if exists sq8_session_rsvps_update on public.sq8_session_rsvps;
create policy sq8_session_rsvps_update
  on public.sq8_session_rsvps
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists sq8_session_rsvps_delete on public.sq8_session_rsvps;
create policy sq8_session_rsvps_delete
  on public.sq8_session_rsvps
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function sq8.limit_session_rsvp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  seats integer;
begin
  if new.response is distinct from 'in' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.response = 'in' then
    return new;
  end if;
  select count(*)
    into seats
  from public.sq8_session_rsvps
  where session_id = new.session_id
    and response = 'in'
    and user_id is distinct from new.user_id;
  if seats >= 8 then
    raise exception 'session_full' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function sq8.limit_session_rsvp() from public, anon, authenticated;

drop trigger if exists sq8_session_rsvps_cap on public.sq8_session_rsvps;
create trigger sq8_session_rsvps_cap
  before insert or update on public.sq8_session_rsvps
  for each row
  execute function sq8.limit_session_rsvp();

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
  foreach table_name in array array['sq8_sessions', 'sq8_session_rsvps']
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
