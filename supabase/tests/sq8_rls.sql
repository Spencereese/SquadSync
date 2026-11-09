-- Proves the slice 2 rules against a local database. Not for the live project.

\set ON_ERROR_STOP on

-- Fixture. The signup trigger writes profiles, including default_game.
insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000001', 'spencer@example.com'),
  ('a0000000-0000-4000-8000-000000000002', 'friend2@example.com'),
  ('a0000000-0000-4000-8000-000000000003', 'friend3@example.com'),
  ('a0000000-0000-4000-8000-000000000004', 'friend4@example.com'),
  ('a0000000-0000-4000-8000-000000000005', 'friend5@example.com'),
  ('a0000000-0000-4000-8000-000000000006', 'friend6@example.com'),
  ('a0000000-0000-4000-8000-000000000007', 'friend7@example.com'),
  ('a0000000-0000-4000-8000-000000000008', 'friend8@example.com'),
  ('a0000000-0000-4000-8000-000000000009', 'ninth@example.com'),
  ('a0000000-0000-4000-8000-00000000000a', 'outsider@example.com');

do $$
declare
  game text;
begin
  select default_game into game
  from public.sq8_profiles
  where id = 'a0000000-0000-4000-8000-000000000001';
  if game is distinct from 'Call of Duty' then
    raise exception 'owner default game is %, expected Call of Duty', game;
  end if;
end $$;

insert into public.sq8_squads (id, owner_id)
values (
  'b0000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000001'
);

insert into public.sq8_squad_members (squad_id, user_id) values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000005'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000006'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000007'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000008');

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_squad_members
  where squad_id = 'b0000000-0000-4000-8000-000000000001';
  if n <> 8 then
    raise exception 'expected 8 members before the cap test, found %', n;
  end if;
end $$;

do $$
begin
  insert into public.sq8_squad_members (squad_id, user_id)
  values (
    'b0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000009'
  );
  raise exception 'ninth member was accepted';
exception
  when check_violation then
    if sqlerrm not like '%sq8_squad_full%' then
      raise;
    end if;
end $$;

do $$
begin
  delete from public.sq8_squad_members
  where squad_id = 'b0000000-0000-4000-8000-000000000001'
    and user_id = 'a0000000-0000-4000-8000-000000000001';
  raise exception 'owner removal was accepted';
exception
  when check_violation then
    if sqlerrm not like '%sq8_owner_protected%' then
      raise;
    end if;
end $$;

insert into public.sq8_messages (id, squad_id, sender_id, body, sent_at)
values (
  'c0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000001',
  'hello',
  timestamptz '2026-11-02 12:00:00+00'
);

insert into public.sq8_chat_read_state (user_id, squad_id, last_read_at, last_read_id)
values (
  'a0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  timestamptz '2026-11-02 12:00:00+00',
  'c0000000-0000-4000-8000-000000000001'
);

do $$
declare
  published boolean;
  table_name text;
begin
  select exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_messages'
  ) into published;
  if not published then
    raise exception 'sq8_messages is not in supabase_realtime';
  end if;
  foreach table_name in array array['sq8_squad_members', 'sq8_check_ins']
  loop
    select exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) into published;
    if not published then
      raise exception '% is not in supabase_realtime', table_name;
    end if;
  end loop;
end $$;

-- A member can read a squad mate's profile. An outsider cannot.
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', false);
set role authenticated;

do $$
declare
  game text;
begin
  select default_game into game
  from public.sq8_profiles
  where id = 'a0000000-0000-4000-8000-000000000001';
  if game is distinct from 'Call of Duty' then
    raise exception 'member could not read the owner profile, got %', game;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-00000000000a', false);

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_profiles
  where id = 'a0000000-0000-4000-8000-000000000001';
  if n <> 0 then
    raise exception 'outsider read the owner profile';
  end if;
end $$;

-- Member can read the message. Non-member cannot.
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', false);

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_messages;
  if n <> 1 then
    raise exception 'member saw % messages, expected 1', n;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-00000000000a', false);

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_messages;
  if n <> 0 then
    raise exception 'non-member saw % messages', n;
  end if;
end $$;

-- Cannot insert a row as someone else.
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', false);

do $$
begin
  insert into public.sq8_messages (id, squad_id, sender_id, body, sent_at)
  values (
    'c0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'spoofed',
    timestamptz '2026-11-02 12:01:00+00'
  );
  raise exception 'insert as someone else was accepted';
exception
  when insufficient_privilege then
    null;
end $$;

-- Duplicate client id conflicts.
do $$
begin
  insert into public.sq8_messages (id, squad_id, sender_id, body, sent_at)
  values (
    'c0000000-0000-4000-8000-000000000099',
    'b0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000002',
    'once',
    timestamptz '2026-11-02 12:02:00+00'
  );
  begin
    insert into public.sq8_messages (id, squad_id, sender_id, body, sent_at)
    values (
      'c0000000-0000-4000-8000-000000000099',
      'b0000000-0000-4000-8000-000000000001',
      'a0000000-0000-4000-8000-000000000002',
      'twice',
      timestamptz '2026-11-02 12:03:00+00'
    );
    raise exception 'duplicate id was accepted';
  exception
    when unique_violation then
      null;
  end;
end $$;

-- Read state is private to its user.
do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_chat_read_state
  where user_id = 'a0000000-0000-4000-8000-000000000001';
  if n <> 0 then
    raise exception 'friend read the owner read-state row';
  end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000001', false);
set role authenticated;

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_chat_read_state
  where user_id = 'a0000000-0000-4000-8000-000000000001';
  if n <> 1 then
    raise exception 'owner could not read their own read state';
  end if;
end $$;

reset role;
