-- A code issued for 6 free seats must still fill the squad after someone
-- leaves and rejoins. Not the live project. The two-session race at 7
-- stays in sq8_invite_race.sh.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('f0000000-0000-4000-8000-000000000001', 'cap-owner@example.com'),
  ('f0000000-0000-4000-8000-000000000002', 'cap-mate@example.com'),
  ('f0000000-0000-4000-8000-000000000003', 'cap-rejoiner@example.com'),
  ('f0000000-0000-4000-8000-000000000004', 'cap4@example.com'),
  ('f0000000-0000-4000-8000-000000000005', 'cap5@example.com'),
  ('f0000000-0000-4000-8000-000000000006', 'cap6@example.com'),
  ('f0000000-0000-4000-8000-000000000007', 'cap7@example.com'),
  ('f0000000-0000-4000-8000-000000000008', 'cap8@example.com'),
  ('f0000000-0000-4000-8000-000000000009', 'cap9@example.com'),
  ('f0000000-0000-4000-8000-00000000000a', 'cap-fresh@example.com');

insert into public.sq8_squads (id, owner_id) values
  ('f1000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001'),
  ('f1000000-0000-4000-8000-000000000002', 'f0000000-0000-4000-8000-00000000000a');

insert into public.sq8_squad_members (squad_id, user_id) values
  ('f1000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000002');

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses
) values (
  'f1000000-0000-4000-8000-000000000001',
  'SEAT2345',
  'f0000000-0000-4000-8000-000000000001',
  now() + interval '7 days',
  6
);

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses
) values (
  'f1000000-0000-4000-8000-000000000002',
  'DEAD2345',
  'f0000000-0000-4000-8000-00000000000a',
  now() - interval '1 hour',
  6
);

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses, revoked_at
) values (
  'f1000000-0000-4000-8000-000000000002',
  'NXPT2345',
  'f0000000-0000-4000-8000-00000000000a',
  now() + interval '7 days',
  6,
  now()
);

do $$
declare
  result jsonb;
  members integer;
  used integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000009',
    true
  );
  result := public.sq8_join_with_code('DEAD2345');
  if result ->> 'error' is distinct from 'expired' then
    raise exception 'expired code returned %', result;
  end if;
  result := public.sq8_join_with_code('NXPT2345');
  if result ->> 'error' is distinct from 'invalid' then
    raise exception 'revoked code returned %', result;
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000003',
    true
  );
  result := public.sq8_join_with_code('SEAT2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'first join failed: %', result;
  end if;

  delete from public.sq8_squad_members
  where squad_id = 'f1000000-0000-4000-8000-000000000001'
    and user_id = 'f0000000-0000-4000-8000-000000000003';

  result := public.sq8_join_with_code('SEAT2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'rejoin after removal failed: %', result;
  end if;
  result := public.sq8_join_with_code('SEAT2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'idempotent rejoin failed: %', result;
  end if;

  select count(*) into members
  from public.sq8_squad_members
  where squad_id = 'f1000000-0000-4000-8000-000000000001';
  select uses into used from public.sq8_invites where code = 'SEAT2345';
  if members <> 3 or used <> 2 then
    raise exception 'after rejoin members % uses %', members, used;
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000004',
    true
  );
  result := public.sq8_join_with_code('SEAT2345');
  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000005',
    true
  );
  result := public.sq8_join_with_code('SEAT2345');
  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000006',
    true
  );
  result := public.sq8_join_with_code('SEAT2345');
  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000007',
    true
  );
  result := public.sq8_join_with_code('SEAT2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'fourth extra join failed: %', result;
  end if;

  select count(*) into members
  from public.sq8_squad_members
  where squad_id = 'f1000000-0000-4000-8000-000000000001';
  select uses into used from public.sq8_invites where code = 'SEAT2345';
  if members <> 7 or used <> 6 then
    raise exception 'before last seat members % uses %', members, used;
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000008',
    true
  );
  result := public.sq8_join_with_code('SEAT2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception '8th member was refused: %', result;
  end if;

  select count(*) into members
  from public.sq8_squad_members
  where squad_id = 'f1000000-0000-4000-8000-000000000001';
  select uses into used from public.sq8_invites where code = 'SEAT2345';
  if members <> 8 or used <> 7 then
    raise exception 'full squad members % uses %', members, used;
  end if;

  result := public.sq8_join_with_code('SEAT2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'seated member rejoin failed: %', result;
  end if;
  select uses into used from public.sq8_invites where code = 'SEAT2345';
  if used <> 7 then
    raise exception 'seated rejoin changed uses to %', used;
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-000000000009',
    true
  );
  result := public.sq8_join_with_code('SEAT2345');
  if result ->> 'error' is distinct from 'full' then
    raise exception '9th join returned %', result;
  end if;
  select count(*) into members
  from public.sq8_squad_members
  where squad_id = 'f1000000-0000-4000-8000-000000000001';
  if members <> 8 then
    raise exception '9th join changed the squad to %', members;
  end if;
end $$;

do $$
declare
  result jsonb;
  cap integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    'f0000000-0000-4000-8000-00000000000a',
    true
  );
  result := public.sq8_create_invite();
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'create invite failed: %', result;
  end if;
  select max_uses into cap
  from public.sq8_invites
  where code = result ->> 'code';
  if cap <> 8 then
    raise exception 'new code max_uses is % instead of a neutral 8', cap;
  end if;
end $$;

\ir ../migrations/20261109_0011_invite_capacity_by_members.sql

do $$
begin
  if has_function_privilege(
    'anon', 'public.sq8_join_with_code(text)', 'execute'
  ) then
    raise exception '0011 left anon able to join';
  end if;
  if has_function_privilege(
    'anon', 'public.sq8_create_invite()', 'execute'
  ) then
    raise exception '0011 left anon able to create an invite';
  end if;
  if not has_function_privilege(
    'authenticated', 'public.sq8_join_with_code(text)', 'execute'
  ) then
    raise exception '0011 removed authenticated join';
  end if;
  if not has_function_privilege(
    'authenticated', 'public.sq8_create_invite()', 'execute'
  ) then
    raise exception '0011 removed authenticated create';
  end if;
  if has_function_privilege(
    'anon', 'sq8.join_with_code(text)', 'execute'
  ) then
    raise exception '0011 granted anon the inner join';
  end if;
end $$;
