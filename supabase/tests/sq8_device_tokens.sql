-- Device tokens stay private to the signed-in person.
-- The squad target list excludes the sender. Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('c5000000-0000-4000-8000-000000000001', 'push-owner@example.com'),
  ('c5000000-0000-4000-8000-000000000002', 'push-mate@example.com'),
  ('c5000000-0000-4000-8000-000000000003', 'push-outsider@example.com');

insert into public.sq8_squads (id, owner_id)
values (
  'c5100000-0000-4000-8000-000000000001',
  'c5000000-0000-4000-8000-000000000001'
);

insert into public.sq8_squad_members (squad_id, user_id)
values (
  'c5100000-0000-4000-8000-000000000001',
  'c5000000-0000-4000-8000-000000000002'
);

set role anon;

do $$
begin
  perform public.sq8_register_device_token('anon-token', 'ios');
  raise exception 'anon registered a token';
exception
  when insufficient_privilege then
    null;
end $$;

do $$
begin
  perform 1 from public.sq8_device_tokens;
  raise exception 'anon read device tokens';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c5000000-0000-4000-8000-000000000002',
  false
);
set role authenticated;

select public.sq8_register_device_token('mate-phone', 'ios');
select public.sq8_register_device_token('mate-phone', 'android');

do $$
declare
  n integer;
  platform text;
begin
  select count(*), max(sq8_device_tokens.platform)
    into n, platform
  from public.sq8_device_tokens
  where user_id = 'c5000000-0000-4000-8000-000000000002';
  if n <> 1 or platform <> 'android' then
    raise exception 'upsert left % rows platform %', n, platform;
  end if;
end $$;

do $$
begin
  insert into public.sq8_device_tokens (user_id, token, platform)
  values (
    'c5000000-0000-4000-8000-000000000001',
    'stolen',
    'ios'
  );
  raise exception 'member inserted a token for someone else';
exception
  when insufficient_privilege then
    null;
end $$;

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_device_tokens;
  if n <> 1 then
    raise exception 'member saw % token rows', n;
  end if;
end $$;

do $$
begin
  perform public.sq8_register_device_token('   ', 'ios');
  raise exception 'blank token was stored';
exception
  when sqlstate '22023' then
    null;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c5000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

select public.sq8_register_device_token('owner-phone', 'ios');

do $$
begin
  perform public.sq8_message_push_targets(
    'c5100000-0000-4000-8000-000000000001',
    'c5000000-0000-4000-8000-000000000001'
  );
  raise exception 'authenticated listed push targets';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;

do $$
declare
  n integer;
  seen uuid;
begin
  select count(*)
    into n
  from sq8.message_push_targets(
    'c5100000-0000-4000-8000-000000000001',
    'c5000000-0000-4000-8000-000000000001'
  );
  select user_id
    into seen
  from sq8.message_push_targets(
    'c5100000-0000-4000-8000-000000000001',
    'c5000000-0000-4000-8000-000000000001'
  )
  limit 1;
  if n <> 1 or seen <> 'c5000000-0000-4000-8000-000000000002' then
    raise exception 'targets were % for %', n, seen;
  end if;

  select count(*)
    into n
  from sq8.message_push_targets(
    'c5100000-0000-4000-8000-000000000001',
    'c5000000-0000-4000-8000-000000000002'
  )
  where user_id = 'c5000000-0000-4000-8000-000000000002';
  if n <> 0 then
    raise exception 'sender was included in their own push targets';
  end if;
end $$;
