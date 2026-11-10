-- Sessions: membership, creator or owner edits, self-only RSVP, cap of 8.
-- Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email)
select
  ('ca000000-0000-4000-8000-00000000000' || n::text)::uuid,
  'session-' || n::text || '@example.com'
from generate_series(1, 9) as n;

insert into public.sq8_squads (id, owner_id)
values (
  'ca100000-0000-4000-8000-000000000001',
  'ca000000-0000-4000-8000-000000000001'
);

insert into public.sq8_squad_members (squad_id, user_id)
select
  'ca100000-0000-4000-8000-000000000001',
  ('ca000000-0000-4000-8000-00000000000' || n::text)::uuid
from generate_series(2, 8) as n;

select set_config(
  'request.jwt.claim.sub',
  'ca000000-0000-4000-8000-000000000002',
  false
);
set role authenticated;

insert into public.sq8_sessions (squad_id, creator_id, game, starts_at, note)
values (
  'ca100000-0000-4000-8000-000000000001',
  'ca000000-0000-4000-8000-000000000002',
  'Halo, Infinite',
  timestamptz '2026-11-10 21:00:00+00',
  'bring mics'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'ca000000-0000-4000-8000-000000000003',
  false
);
set role authenticated;

do $$
declare
  changed integer;
begin
  update public.sq8_sessions
  set game = 'Stolen'
  where creator_id = 'ca000000-0000-4000-8000-000000000002';
  get diagnostics changed = row_count;
  if changed is distinct from 0 then
    raise exception 'a member edited someone else''s session';
  end if;
end $$;

do $$
begin
  insert into public.sq8_session_rsvps (session_id, user_id, response)
  select id, 'ca000000-0000-4000-8000-000000000002', 'in'
  from public.sq8_sessions
  where creator_id = 'ca000000-0000-4000-8000-000000000002';
  raise exception 'rsvp was written for someone else';
exception
  when insufficient_privilege then
    null;
end $$;

insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000003', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';

reset role;
set role anon;

do $$
begin
  perform 1 from public.sq8_sessions;
  raise exception 'anon read sessions';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000001', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000001', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';
reset role;

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000002', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000002', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';
reset role;

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000004', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000004', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';
reset role;

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000005', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000005', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';
reset role;

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000006', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000006', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';
reset role;

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000007', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000007', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';
reset role;

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000008', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
select id, 'ca000000-0000-4000-8000-000000000008', 'in'
from public.sq8_sessions
where creator_id = 'ca000000-0000-4000-8000-000000000002';
reset role;

set session_replication_role = replica;
insert into public.sq8_squad_members (squad_id, user_id)
values (
  'ca100000-0000-4000-8000-000000000001',
  'ca000000-0000-4000-8000-000000000009'
);
set session_replication_role = origin;

select set_config(
  'request.jwt.claim.sub',
  'ca000000-0000-4000-8000-000000000009',
  false
);
set role authenticated;

do $$
declare
  session uuid;
begin
  select id into session
  from public.sq8_sessions
  where creator_id = 'ca000000-0000-4000-8000-000000000002';
  begin
    insert into public.sq8_session_rsvps (session_id, user_id, response)
    values (
      session,
      'ca000000-0000-4000-8000-000000000009',
      'in'
    );
    raise exception 'a ninth in was accepted';
  exception
    when sqlstate 'P0001' then
      null;
  end;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'ca000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

update public.sq8_sessions
set cancelled_at = now()
where creator_id = 'ca000000-0000-4000-8000-000000000002';

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_sessions
  where cancelled_at is not null;
  if n is distinct from 1 then
    raise exception 'owner cancel left % rows', n;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_sessions'
  ) or not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_session_rsvps'
  ) then
    raise exception 'session tables are missing from supabase_realtime';
  end if;
end $$;

reset role;
