-- 0024 side-thread guards: who may add whom, the DM cap, and message squads.
-- Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email)
select
  ('cb000000-0000-4000-8000-00000000000' || n::text)::uuid,
  'thread-' || n::text || '@example.com'
from generate_series(1, 6) as n;

-- Squad A: 1 (owner), 2, 3, 4. Squad B: 5 (owner). A person is in one squad at a time.
insert into public.sq8_squads (id, owner_id)
values
  ('cb100000-0000-4000-8000-00000000000a', 'cb000000-0000-4000-8000-000000000001'),
  ('cb100000-0000-4000-8000-00000000000b', 'cb000000-0000-4000-8000-000000000005');

insert into public.sq8_squad_members (squad_id, user_id)
values
  ('cb100000-0000-4000-8000-00000000000a', 'cb000000-0000-4000-8000-000000000002'),
  ('cb100000-0000-4000-8000-00000000000a', 'cb000000-0000-4000-8000-000000000003'),
  ('cb100000-0000-4000-8000-00000000000a', 'cb000000-0000-4000-8000-000000000004');

insert into public.sq8_threads (id, squad_id, kind, title, created_by)
values
  ('cb200000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-00000000000a', 'side_group', 'Ranked', 'cb000000-0000-4000-8000-000000000001'),
  ('cb200000-0000-4000-8000-000000000002', 'cb100000-0000-4000-8000-00000000000a', 'dm', null, 'cb000000-0000-4000-8000-000000000001');

create or replace function pg_temp.as_user(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', 'cb000000-0000-4000-8000-00000000000' || n::text, false);
$$;

create or replace function pg_temp.add(thread text, member integer, adder integer) returns text
language plpgsql as $$
begin
  insert into public.sq8_thread_members (thread_id, user_id, added_by)
  values (thread::uuid, ('cb000000-0000-4000-8000-00000000000' || member::text)::uuid,
          ('cb000000-0000-4000-8000-00000000000' || adder::text)::uuid);
  return 'ok';
exception
  when insufficient_privilege then return 'refused';
  when check_violation then return sqlerrm;
end $$;

create or replace function pg_temp.post(thread text, squad text, sender integer) returns text
language plpgsql as $$
begin
  insert into public.sq8_thread_messages (id, thread_id, squad_id, sender_id, body, sent_at)
  values (gen_random_uuid(), thread::uuid, squad::uuid,
          ('cb000000-0000-4000-8000-00000000000' || sender::text)::uuid, 'gg', now());
  return 'ok';
exception
  when insufficient_privilege then return 'refused';
  when check_violation then return sqlerrm;
end $$;

grant execute on all functions in schema pg_temp to authenticated;

create or replace function pg_temp.expect(actual text, wanted text, label text) returns void
language plpgsql as $$
begin
  if actual is distinct from wanted then
    raise exception '%: expected %, got %', label, wanted, actual;
  end if;
end $$;

set role authenticated;

-- (a) The creator seats themself and adds a squadmate.
select pg_temp.as_user(1);
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 1, 1), 'ok', 'creator adds self');
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 2, 1), 'ok', 'creator adds a squadmate');
-- Someone from another squad can't be added.
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 5, 1), 'refused', 'outsider added');

-- A squad member who isn't in the thread can't add themself or anyone else.
select pg_temp.as_user(3);
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 3, 3), 'refused', 'non-member joins a side group');
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 4, 3), 'refused', 'non-member adds someone');
-- added_by must be the caller.
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 3, 1), 'refused', 'added_by spoofed');

-- An existing thread member can add a squadmate.
select pg_temp.as_user(2);
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 3, 2), 'ok', 'member adds a squadmate');

-- (b) A DM caps at two.
select pg_temp.as_user(1);
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000002', 1, 1), 'ok', 'dm creator');
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000002', 2, 1), 'ok', 'dm partner');
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000002', 3, 1), 'sq8_dm_full', 'third person in a dm');
select pg_temp.as_user(2);
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000002', 4, 2), 'sq8_dm_full', 'partner adds a third');
-- A side group has no such cap.
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000001', 4, 2), 'ok', 'side group grows');

-- (c) Messages.
select pg_temp.as_user(2);
select pg_temp.expect(pg_temp.post('cb200000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-00000000000a', 2), 'ok', 'member posts');
-- 2 leaves squad A for squad B but is still listed in A's thread. Posting to
-- that thread under squad B passed 0017 (2 is a member of B and of the thread).
-- The trigger refuses it (it runs before the row level security check).
reset role;
delete from public.sq8_squad_members
where squad_id = 'cb100000-0000-4000-8000-00000000000a'
  and user_id = 'cb000000-0000-4000-8000-000000000002';
insert into public.sq8_squad_members (squad_id, user_id)
values ('cb100000-0000-4000-8000-00000000000b', 'cb000000-0000-4000-8000-000000000002');
set role authenticated;
select pg_temp.as_user(2);
select pg_temp.expect(pg_temp.post('cb200000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-00000000000b', 2), 'sq8_thread_squad_mismatch', 'message filed under the wrong squad');
select pg_temp.expect(pg_temp.post('cb200000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-00000000000a', 2), 'refused', 'former member posts to the old squad');
-- A squad member outside the DM can't post in it.
select pg_temp.as_user(3);
select pg_temp.expect(pg_temp.post('cb200000-0000-4000-8000-000000000002', 'cb100000-0000-4000-8000-00000000000a', 3), 'refused', 'non-member posts to a dm');
-- Can't post as someone else.
select pg_temp.expect(pg_temp.post('cb200000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-00000000000a', 2), 'refused', 'sender spoofed');

reset role;
-- The trigger holds even for a writer that skips row level security.
select pg_temp.expect(pg_temp.post('cb200000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-00000000000b', 2), 'sq8_thread_squad_mismatch', 'owner role files under the wrong squad');
select pg_temp.expect(pg_temp.add('cb200000-0000-4000-8000-000000000002', 3, 1), 'sq8_dm_full', 'owner role overfills a dm');

set role anon;
do $$
begin
  perform 1 from public.sq8_thread_members;
  raise exception 'anon read thread members';
exception
  when insufficient_privilege then null;
end $$;
reset role;

select 'sq8 side thread guards passed';
