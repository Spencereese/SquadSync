-- Starting a side thread from the app: the same two requests the client sends, under
-- the live 0017 + 0024 policies, as a signed-in user. No creation RPC exists, so this
-- is the whole path. Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email)
select
  ('ce000000-0000-4000-8000-00000000000' || n::text)::uuid,
  'create-' || n::text || '@example.com'
from generate_series(1, 6) as n;

-- Squad A: 1 (owner), 2, 3, 4. Squad B: 5 (owner). 6 is in no squad.
insert into public.sq8_squads (id, owner_id)
values
  ('ce100000-0000-4000-8000-00000000000a', 'ce000000-0000-4000-8000-000000000001'),
  ('ce100000-0000-4000-8000-00000000000b', 'ce000000-0000-4000-8000-000000000005');

insert into public.sq8_squad_members (squad_id, user_id)
values
  ('ce100000-0000-4000-8000-00000000000a', 'ce000000-0000-4000-8000-000000000002'),
  ('ce100000-0000-4000-8000-00000000000a', 'ce000000-0000-4000-8000-000000000003'),
  ('ce100000-0000-4000-8000-00000000000a', 'ce000000-0000-4000-8000-000000000004');

create or replace function pg_temp.as_user(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', 'ce000000-0000-4000-8000-00000000000' || n::text, false);
$$;

create or replace function pg_temp.uid(n integer) returns uuid language sql as $$
  select ('ce000000-0000-4000-8000-00000000000' || n::text)::uuid;
$$;

-- Request 1: POST sq8_threads with Prefer: return=minimal,resolution=ignore-duplicates
-- (INSERT ... ON CONFLICT DO NOTHING, nothing read back).
create or replace function pg_temp.make(thread text, squad text, kind text, title text, creator integer) returns text
language plpgsql as $$
begin
  insert into public.sq8_threads (id, squad_id, kind, title, created_by)
  values (thread::uuid, squad::uuid, kind, title, pg_temp.uid(creator))
  on conflict do nothing;
  return 'ok';
exception
  when insufficient_privilege then return 'refused';
  when check_violation then return 'check';
end $$;

-- Request 2: one bulk POST to sq8_thread_members, the creator first, all or nothing.
create or replace function pg_temp.seat(thread text, adder integer, people integer[]) returns text
language plpgsql as $$
begin
  insert into public.sq8_thread_members (thread_id, user_id, added_by)
  select thread::uuid, pg_temp.uid(person), pg_temp.uid(adder)
  from unnest(people) with ordinality as picked(person, position)
  order by position
  on conflict do nothing;
  return 'ok';
exception
  when insufficient_privilege then return 'refused';
  when check_violation then return sqlerrm;
end $$;

create or replace function pg_temp.visible_threads() returns integer language sql as $$
  select count(*)::integer from public.sq8_threads where id::text like 'ce2%';
$$;

create or replace function pg_temp.visible_members(thread text) returns integer language sql as $$
  select count(*)::integer from public.sq8_thread_members where thread_id = thread::uuid;
$$;

grant execute on all functions in schema pg_temp to authenticated;

create or replace function pg_temp.expect(actual text, wanted text, label text) returns void
language plpgsql as $$
begin
  if actual is distinct from wanted then
    raise exception '%: expected %, got %', label, wanted, actual;
  end if;
end $$;

-- What the table holds, ignoring RLS (run as the owner role).
create or replace function pg_temp.stored_members(thread text) returns text language sql as $$
  select count(*)::text from public.sq8_thread_members where thread_id = thread::uuid;
$$;
create or replace function pg_temp.stored_threads(thread text) returns text language sql as $$
  select count(*)::text from public.sq8_threads where id = thread::uuid;
$$;

set role authenticated;

-- (a) A side group of 1 + 2 + 3.
select pg_temp.as_user(1);
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000001', 'ce100000-0000-4000-8000-00000000000a', 'side_group', 'Ranked', 1), 'ok', 'creator makes a group');
-- The creator can't read the thread until seated: that's why the client reads nothing back.
select pg_temp.expect(pg_temp.visible_threads()::text, '0', 'unseated creator sees the thread');
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000001', 1, array[1, 2, 3]), 'ok', 'bulk seating');
select pg_temp.expect(pg_temp.visible_threads()::text, '1', 'seated creator sees the thread');
select pg_temp.expect(pg_temp.visible_members('ce200000-0000-4000-8000-000000000001')::text, '3', 'creator sees all three seats');

-- A retry after a lost response changes nothing and raises nothing.
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000001', 'ce100000-0000-4000-8000-00000000000a', 'side_group', 'Ranked', 1), 'ok', 'thread retry');
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000001', 1, array[1, 2, 3]), 'ok', 'seating retry');
select pg_temp.expect(pg_temp.visible_threads()::text, '1', 'retry made a second thread');
select pg_temp.expect(pg_temp.visible_members('ce200000-0000-4000-8000-000000000001')::text, '3', 'retry doubled the seats');

-- The people picked see it; a squadmate who wasn't picked doesn't.
select pg_temp.as_user(2);
select pg_temp.expect(pg_temp.visible_threads()::text, '1', 'picked member sees the group');
select pg_temp.as_user(3);
select pg_temp.expect(pg_temp.visible_threads()::text, '1', 'second picked member sees the group');
select pg_temp.as_user(4);
select pg_temp.expect(pg_temp.visible_threads()::text, '0', 'unpicked squadmate sees the group');
select pg_temp.expect(pg_temp.visible_members('ce200000-0000-4000-8000-000000000001')::text, '0', 'unpicked squadmate sees the seats');
-- ...and can't seat themself.
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000001', 4, array[4]), 'refused', 'unpicked squadmate joins');
-- Someone outside the squad sees nothing either.
select pg_temp.as_user(5);
select pg_temp.expect(pg_temp.visible_threads()::text, '0', 'other squad sees the group');
select pg_temp.as_user(6);
select pg_temp.expect(pg_temp.visible_threads()::text, '0', 'no-squad user sees the group');

-- (b) A DM between 1 and 2, no title.
select pg_temp.as_user(1);
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000002', 'ce100000-0000-4000-8000-00000000000a', 'dm', null, 1), 'ok', 'creator makes a dm');
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000002', 1, array[1, 2]), 'ok', 'dm seating');
select pg_temp.expect(pg_temp.visible_members('ce200000-0000-4000-8000-000000000002')::text, '2', 'dm has two seats');
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000002', 1, array[3]), 'sq8_dm_full', 'third person in the dm');
select pg_temp.as_user(3);
select pg_temp.expect(pg_temp.visible_members('ce200000-0000-4000-8000-000000000002')::text, '0', 'a squadmate reads the dm seats');

-- (c) Refused creations.
select pg_temp.as_user(1);
-- Spoofed creator.
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000003', 'ce100000-0000-4000-8000-00000000000a', 'side_group', 'Spoof', 2), 'refused', 'created_by spoofed');
-- A squad you're not in.
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000004', 'ce100000-0000-4000-8000-00000000000b', 'side_group', 'Other', 1), 'refused', 'thread in another squad');
-- A group without a title.
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000005', 'ce100000-0000-4000-8000-00000000000a', 'side_group', null, 1), 'check', 'untitled group');
-- Someone outside the squad in the bulk: the whole statement fails and seats nobody, so the
-- creator can fix the pick and retry on the same thread.
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000006', 'ce100000-0000-4000-8000-00000000000a', 'side_group', 'Mixed', 1), 'ok', 'thread for the mixed pick');
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000006', 1, array[1, 2, 5]), 'refused', 'outsider in the bulk');
-- The creator who isn't seated yet can still seat the rest (creator or member may add).
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000006', 1, array[1, 2]), 'ok', 'retry after the refused bulk');
select pg_temp.expect(pg_temp.visible_members('ce200000-0000-4000-8000-000000000006')::text, '2', 'retry seats');
-- added_by must be you.
select pg_temp.expect(pg_temp.make('ce200000-0000-4000-8000-000000000007', 'ce100000-0000-4000-8000-00000000000a', 'side_group', 'Added', 1), 'ok', 'thread for spoofed added_by');
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000007', 2, array[1, 2]), 'refused', 'added_by spoofed');
-- Nobody else may seat people in your thread before you do.
select pg_temp.as_user(2);
select pg_temp.expect(pg_temp.seat('ce200000-0000-4000-8000-000000000007', 2, array[2]), 'refused', 'a squadmate seats themself in an unseated thread');

reset role;
-- What was stored: the refused ones left nothing behind but the empty thread the creator can retry.
select pg_temp.expect(pg_temp.stored_threads('ce200000-0000-4000-8000-000000000003'), '0', 'spoofed thread stored');
select pg_temp.expect(pg_temp.stored_threads('ce200000-0000-4000-8000-000000000004'), '0', 'other-squad thread stored');
select pg_temp.expect(pg_temp.stored_threads('ce200000-0000-4000-8000-000000000005'), '0', 'untitled group stored');
select pg_temp.expect(pg_temp.stored_members('ce200000-0000-4000-8000-000000000006'), '2', 'outsider left a seat');
select pg_temp.expect(pg_temp.stored_members('ce200000-0000-4000-8000-000000000007'), '0', 'spoofed seats stored');
select pg_temp.expect(pg_temp.stored_members('ce200000-0000-4000-8000-000000000001'), '3', 'retries doubled the seats');

set role anon;
do $$
begin
  insert into public.sq8_threads (id, squad_id, kind, title, created_by)
  values ('ce200000-0000-4000-8000-000000000009', 'ce100000-0000-4000-8000-00000000000a', 'side_group', 'Anon', 'ce000000-0000-4000-8000-000000000001');
  raise exception 'anon made a thread';
exception
  when insufficient_privilege then null;
end $$;
reset role;

select 'sq8 thread create passed';
