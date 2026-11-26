-- 0026 thread push targets: who a side-thread reply notifies, and who may ask.
-- Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email, raw_user_meta_data)
select
  ('cd000000-0000-4000-8000-00000000000' || n::text)::uuid,
  'tp-' || n::text || '@example.com',
  jsonb_build_object('display_name', 'Player ' || n::text)
from generate_series(1, 6) as n;

-- Squad A: 1 (owner), 2, 3, 4. Squad B: 5 (owner). 6 is in no squad.
insert into public.sq8_squads (id, owner_id)
values
  ('cd100000-0000-4000-8000-00000000000a', 'cd000000-0000-4000-8000-000000000001'),
  ('cd100000-0000-4000-8000-00000000000b', 'cd000000-0000-4000-8000-000000000005');

insert into public.sq8_squad_members (squad_id, user_id)
values
  ('cd100000-0000-4000-8000-00000000000a', 'cd000000-0000-4000-8000-000000000002'),
  ('cd100000-0000-4000-8000-00000000000a', 'cd000000-0000-4000-8000-000000000003'),
  ('cd100000-0000-4000-8000-00000000000a', 'cd000000-0000-4000-8000-000000000004');

-- A side group "Ranked" (1, 2, 3) and a DM (1, 4), both in squad A.
insert into public.sq8_threads (id, squad_id, kind, title, created_by)
values
  ('cd200000-0000-4000-8000-000000000001', 'cd100000-0000-4000-8000-00000000000a', 'side_group', 'Ranked', 'cd000000-0000-4000-8000-000000000001'),
  ('cd200000-0000-4000-8000-000000000002', 'cd100000-0000-4000-8000-00000000000a', 'dm', null, 'cd000000-0000-4000-8000-000000000001');

insert into public.sq8_thread_members (thread_id, user_id, added_by)
values
  ('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000001'),
  ('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002', 'cd000000-0000-4000-8000-000000000001'),
  ('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000003', 'cd000000-0000-4000-8000-000000000001'),
  ('cd200000-0000-4000-8000-000000000002', 'cd000000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000001'),
  ('cd200000-0000-4000-8000-000000000002', 'cd000000-0000-4000-8000-000000000004', 'cd000000-0000-4000-8000-000000000001');

insert into public.sq8_device_tokens (user_id, token, platform)
values
  ('cd000000-0000-4000-8000-000000000001', 'tp-1', 'ios'),
  ('cd000000-0000-4000-8000-000000000002', 'tp-2', 'ios'),
  ('cd000000-0000-4000-8000-000000000002', 'tp-2a', 'android'),
  ('cd000000-0000-4000-8000-000000000003', 'tp-3', 'ios'),
  ('cd000000-0000-4000-8000-000000000004', 'tp-4', 'ios'),
  ('cd000000-0000-4000-8000-000000000005', 'tp-5', 'ios'),
  ('cd000000-0000-4000-8000-000000000006', 'tp-6', 'ios');

create or replace function pg_temp.targets(thread text, sender integer) returns text
language sql as $$
  select coalesce(string_agg(token, ',' order by token), '')
  from public.sq8_thread_push_targets(
    thread::uuid,
    ('cd000000-0000-4000-8000-00000000000' || sender::text)::uuid
  );
$$;

create or replace function pg_temp.expect(actual text, wanted text, label text) returns void
language plpgsql as $$
begin
  if actual is distinct from wanted then
    raise exception '%: expected %, got %', label, wanted, actual;
  end if;
end $$;

-- Thread members only, never the sender, never someone outside the thread.
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000001', 2), 'tp-1,tp-3', 'side group reply from 2');
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000001', 1), 'tp-2,tp-2a,tp-3', 'side group reply from the starter');
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000002', 1), 'tp-4', 'dm reply from 1');
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000002', 4), 'tp-1', 'dm reply from 4');
-- An unknown thread notifies nobody.
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-0000000000ff', 1), '', 'unknown thread');

-- The inner function and the wrapper agree.
select pg_temp.expect(
  (select string_agg(token, ',' order by token) from sq8.thread_push_targets(
    'cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002')),
  'tp-1,tp-3',
  'inner function'
);

-- A device the sender also registered is never pushed (a shared phone).
insert into public.sq8_device_tokens (user_id, token, platform)
values ('cd000000-0000-4000-8000-000000000002', 'tp-3', 'ios');
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000001', 2), 'tp-1', 'shared device skipped');
delete from public.sq8_device_tokens
where user_id = 'cd000000-0000-4000-8000-000000000002' and token = 'tp-3';

-- Someone who left the squad is dropped even though their thread row stays.
delete from public.sq8_squad_members
where squad_id = 'cd100000-0000-4000-8000-00000000000a'
  and user_id = 'cd000000-0000-4000-8000-000000000003';
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000001', 2), 'tp-1', 'former squad member');
-- And joining another squad doesn't bring them back.
insert into public.sq8_squad_members (squad_id, user_id)
values ('cd100000-0000-4000-8000-00000000000b', 'cd000000-0000-4000-8000-000000000003');
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000001', 2), 'tp-1', 'member of another squad');

-- A signed-out device (unregistered token) gets nothing.
delete from public.sq8_device_tokens where token = 'tp-1';
select pg_temp.expect(pg_temp.targets('cd200000-0000-4000-8000-000000000001', 2), '', 'unregistered token');

-- The banner context: kind, title, and the sender's name.
select pg_temp.expect(
  (select thread_kind || '|' || coalesce(thread_title, '-') || '|' || sender_name
   from public.sq8_thread_push_context('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002')),
  'side_group|Ranked|Player 2',
  'side group context'
);
select pg_temp.expect(
  (select thread_kind || '|' || coalesce(thread_title, '-') || '|' || sender_name
   from public.sq8_thread_push_context('cd200000-0000-4000-8000-000000000002', 'cd000000-0000-4000-8000-000000000004')),
  'dm|-|Player 4',
  'dm context'
);
select pg_temp.expect(
  (select count(*)::text from public.sq8_thread_push_context('cd200000-0000-4000-8000-0000000000ff', 'cd000000-0000-4000-8000-000000000001')),
  '0',
  'unknown thread context'
);

-- Nobody signed in, and nobody anonymous, may list targets or read the context.
grant execute on all functions in schema pg_temp to authenticated, anon;
select set_config('request.jwt.claim.sub', 'cd000000-0000-4000-8000-000000000002', false);
set role authenticated;
do $$
begin
  perform public.sq8_thread_push_targets('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002');
  raise exception 'authenticated listed thread push targets';
exception
  when insufficient_privilege then null;
end $$;
do $$
begin
  perform sq8.thread_push_targets('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002');
  raise exception 'authenticated called the inner target function';
exception
  when insufficient_privilege then null;
end $$;
do $$
begin
  perform public.sq8_thread_push_context('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002');
  raise exception 'authenticated read thread push context';
exception
  when insufficient_privilege then null;
end $$;
reset role;

set role anon;
do $$
begin
  perform public.sq8_thread_push_targets('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002');
  raise exception 'anon listed thread push targets';
exception
  when insufficient_privilege then null;
end $$;
do $$
begin
  perform public.sq8_thread_push_context('cd200000-0000-4000-8000-000000000001', 'cd000000-0000-4000-8000-000000000002');
  raise exception 'anon read thread push context';
exception
  when insufficient_privilege then null;
end $$;
reset role;

select 'sq8 thread push targets passed';
