-- Reactions, shared read cursors, and the reply column. Not the live project.
-- Typing has no table.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('c8000000-0000-4000-8000-000000000001', 'chat-owner@example.com'),
  ('c8000000-0000-4000-8000-000000000002', 'chat-alex@example.com'),
  ('c8000000-0000-4000-8000-000000000003', 'chat-outsider@example.com');

insert into public.sq8_squads (id, owner_id) values
  (
    'c8100000-0000-4000-8000-000000000001',
    'c8000000-0000-4000-8000-000000000001'
  ),
  (
    'c8100000-0000-4000-8000-000000000002',
    'c8000000-0000-4000-8000-000000000003'
  );

insert into public.sq8_squad_members (squad_id, user_id) values
  (
    'c8100000-0000-4000-8000-000000000001',
    'c8000000-0000-4000-8000-000000000002'
  );

select set_config(
  'request.jwt.claim.sub',
  'c8000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

insert into public.sq8_messages (id, squad_id, sender_id, body, sent_at)
values (
  'c8200000-0000-4000-8000-000000000001',
  'c8100000-0000-4000-8000-000000000001',
  'c8000000-0000-4000-8000-000000000001',
  'hello',
  now()
);

insert into public.sq8_messages (
  id, squad_id, sender_id, body, sent_at, reply_to_id
)
values (
  'c8200000-0000-4000-8000-000000000002',
  'c8100000-0000-4000-8000-000000000001',
  'c8000000-0000-4000-8000-000000000001',
  'reply',
  now(),
  'c8200000-0000-4000-8000-000000000001'
);

insert into public.sq8_message_reactions (message_id, squad_id, user_id, emoji)
values (
  'c8200000-0000-4000-8000-000000000001',
  'c8100000-0000-4000-8000-000000000001',
  'c8000000-0000-4000-8000-000000000001',
  '👍'
);

do $$
begin
  insert into public.sq8_message_reactions (message_id, squad_id, user_id, emoji)
  values (
    'c8200000-0000-4000-8000-000000000001',
    'c8100000-0000-4000-8000-000000000001',
    'c8000000-0000-4000-8000-000000000001',
    'nope'
  );
  raise exception 'an unknown emoji was stored';
exception
  when check_violation then
    null;
end $$;

do $$
begin
  insert into public.sq8_message_reactions (message_id, squad_id, user_id, emoji)
  values (
    'c8200000-0000-4000-8000-000000000001',
    'c8100000-0000-4000-8000-000000000001',
    'c8000000-0000-4000-8000-000000000002',
    '🔥'
  );
  raise exception 'stored a reaction as someone else';
exception
  when insufficient_privilege then
    null;
end $$;

insert into public.sq8_message_reads (user_id, squad_id, last_read_at, last_read_id)
values (
  'c8000000-0000-4000-8000-000000000001',
  'c8100000-0000-4000-8000-000000000001',
  now(),
  'c8200000-0000-4000-8000-000000000002'
);

reset role;
set role anon;

do $$
begin
  perform 1 from public.sq8_message_reactions;
  raise exception 'anon read reactions';
exception
  when insufficient_privilege then
    null;
end $$;

do $$
begin
  perform 1 from public.sq8_message_reads;
  raise exception 'anon read receipts';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c8000000-0000-4000-8000-000000000002',
  false
);
set role authenticated;

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_message_reactions;
  if n is distinct from 1 then
    raise exception 'alex saw % reactions', n;
  end if;
  select count(*) into n from public.sq8_message_reads;
  if n is distinct from 1 then
    raise exception 'alex saw % receipts', n;
  end if;
end $$;

insert into public.sq8_message_reactions (message_id, squad_id, user_id, emoji)
values (
  'c8200000-0000-4000-8000-000000000001',
  'c8100000-0000-4000-8000-000000000001',
  'c8000000-0000-4000-8000-000000000002',
  '👍'
);

delete from public.sq8_message_reactions
where user_id = 'c8000000-0000-4000-8000-000000000002'
  and emoji = '👍';

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_message_reactions
  where user_id = 'c8000000-0000-4000-8000-000000000001';
  if n is distinct from 1 then
    raise exception 'alex deleted someone else''s reaction, % left', n;
  end if;
end $$;

do $$
declare
  changed integer;
begin
  update public.sq8_message_reads
  set last_read_id = 'c8200000-0000-4000-8000-000000000001'
  where user_id = 'c8000000-0000-4000-8000-000000000001';
  get diagnostics changed = row_count;
  if changed is distinct from 0 then
    raise exception 'alex rewrote % receipt rows', changed;
  end if;
end $$;

insert into public.sq8_message_reads (user_id, squad_id, last_read_at, last_read_id)
values (
  'c8000000-0000-4000-8000-000000000002',
  'c8100000-0000-4000-8000-000000000001',
  now(),
  'c8200000-0000-4000-8000-000000000001'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c8000000-0000-4000-8000-000000000003',
  false
);
set role authenticated;

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_message_reactions;
  if n is distinct from 0 then
    raise exception 'an outsider saw % reactions', n;
  end if;
  select count(*) into n from public.sq8_message_reads;
  if n is distinct from 0 then
    raise exception 'an outsider saw % receipts', n;
  end if;
end $$;

reset role;

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'sq8_messages'
      and column_name = 'reply_to_id'
  ) then
    raise exception 'reply_to_id is missing';
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_message_reactions'
  ) or not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_message_reads'
  ) then
    raise exception 'messenger tables are missing from supabase_realtime';
  end if;
end $$;
