-- Invite codes. Not for the live project.
\set ON_ERROR_STOP on

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'sq8_squads'
      and policyname = 'sq8_squads_select_owner'
  ) then
    raise exception 'sq8_squads_select_owner is missing';
  end if;
end $$;

insert into auth.users (id, email) values
  ('e0000000-0000-4000-8000-000000000001', 'inv-owner@example.com'),
  ('e0000000-0000-4000-8000-000000000002', 'inv-mate@example.com'),
  ('e0000000-0000-4000-8000-000000000003', 'inv-joiner@example.com'),
  ('e0000000-0000-4000-8000-000000000004', 'inv-again@example.com'),
  ('e0000000-0000-4000-8000-000000000006', 'inv-busy-owner@example.com'),
  ('e0000000-0000-4000-8000-000000000007', 'inv-busy-mate@example.com'),
  ('e0000000-0000-4000-8000-000000000008', 'inv-empty-owner@example.com'),
  ('e0000000-0000-4000-8000-000000000009', 'inv-other-owner@example.com');

insert into public.sq8_squads (id, owner_id) values
  ('e1000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001'),
  ('e1000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000006'),
  ('e1000000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000000008'),
  ('e1000000-0000-4000-8000-000000000005', 'e0000000-0000-4000-8000-000000000009');

insert into public.sq8_squad_members (squad_id, user_id) values
  ('e1000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000002'),
  ('e1000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000007');

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses
) values (
  'e1000000-0000-4000-8000-000000000001',
  'ABCD2345',
  'e0000000-0000-4000-8000-000000000001',
  now() + interval '7 days',
  7
);

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses, revoked_at
) values (
  'e1000000-0000-4000-8000-000000000001',
  'AWAY2345',
  'e0000000-0000-4000-8000-000000000001',
  now() + interval '7 days',
  7,
  now()
);

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses
) values (
  'e1000000-0000-4000-8000-000000000005',
  'PAST2345',
  'e0000000-0000-4000-8000-000000000009',
  now() - interval '1 hour',
  7
);

create temp table invite_probe (label text primary key, body jsonb);
grant all on invite_probe to authenticated;

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000001', false);
set role authenticated;

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_invites where code = 'ABCD2345';
  if n <> 1 then
    raise exception 'owner saw % invite rows', n;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000002', false);

do $$
declare
  n integer;
  result jsonb;
begin
  select count(*) into n from public.sq8_invites;
  if n <> 0 then
    raise exception 'non-owner read % invite rows', n;
  end if;
  result := public.sq8_create_invite();
  if result ->> 'error' is distinct from 'not_owner' then
    raise exception 'mate created a code: %', result;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000003', false);

do $$
declare
  result jsonb;
begin
  result := public.sq8_join_with_code('ABCD2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'valid join failed: %', result;
  end if;
  result := public.sq8_join_with_code('abcd-2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'rejoin failed: %', result;
  end if;
end $$;

reset role;

do $$
declare
  n integer;
  used integer;
begin
  select count(*) into n
  from public.sq8_squad_members
  where user_id = 'e0000000-0000-4000-8000-000000000003'
    and squad_id = 'e1000000-0000-4000-8000-000000000001';
  select uses into used from public.sq8_invites where code = 'ABCD2345';
  if n <> 1 or used <> 1 then
    raise exception 'rejoin changed membership % or uses %', n, used;
  end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000004', false);

do $$
declare
  result jsonb;
begin
  result := public.sq8_join_with_code('PAST2345');
  if result ->> 'error' is distinct from 'expired' then
    raise exception 'expired code returned %', result;
  end if;
  result := public.sq8_join_with_code('AWAY2345');
  if result ->> 'error' is distinct from 'invalid' then
    raise exception 'revoked code returned %', result;
  end if;
  result := public.sq8_join_with_code('NOPE9999');
  if result ->> 'error' is distinct from 'invalid' then
    raise exception 'unknown code returned %', result;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000007', false);

do $$
declare
  result jsonb;
begin
  result := public.sq8_join_with_code('ABCD2345');
  if result ->> 'error' is distinct from 'already_in_squad' then
    raise exception 'member elsewhere returned %', result;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000006', false);

do $$
declare
  result jsonb;
begin
  result := public.sq8_join_with_code('ABCD2345');
  if result ->> 'error' is distinct from 'owns_squad_with_members' then
    raise exception 'busy owner returned %', result;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000008', false);

do $$
declare
  result jsonb;
begin
  result := public.sq8_join_with_code('ABCD2345');
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'empty owner join failed: %', result;
  end if;
end $$;

reset role;

do $$
declare
  old_n integer;
  new_n integer;
begin
  select count(*) into old_n
  from public.sq8_squads
  where id = 'e1000000-0000-4000-8000-000000000003';
  select count(*) into new_n
  from public.sq8_squad_members
  where user_id = 'e0000000-0000-4000-8000-000000000008'
    and squad_id = 'e1000000-0000-4000-8000-000000000001';
  if old_n <> 0 or new_n <> 1 then
    raise exception 'empty squad left % and new seat %', old_n, new_n;
  end if;
end $$;

-- Rotation invalidates the previous code.
select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000001', false);
set role authenticated;

insert into invite_probe (label, body)
values ('first', public.sq8_create_invite());

insert into invite_probe (label, body)
values ('second', public.sq8_create_invite());

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-000000000004', false);

do $$
declare
  first_code text;
  second_code text;
  result jsonb;
begin
  select body ->> 'code' into first_code from invite_probe where label = 'first';
  select body ->> 'code' into second_code from invite_probe where label = 'second';
  if first_code !~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$'
     or second_code !~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$' then
    raise exception 'rotated codes are not typeable: % %', first_code, second_code;
  end if;
  result := public.sq8_join_with_code(first_code);
  if result ->> 'error' is distinct from 'invalid' then
    raise exception 'rotated code still joined: %', result;
  end if;
  result := public.sq8_join_with_code(second_code);
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'current code failed: %', result;
  end if;
end $$;

reset role;

insert into auth.users (id, email)
select
  ('e2000000-0000-4000-8000-00000000000' || n::text)::uuid,
  'full' || n::text || '@example.com'
from generate_series(1, 9) as n;

insert into public.sq8_squads (id, owner_id)
values (
  'e2000000-0000-4000-8000-000000000001',
  'e2000000-0000-4000-8000-000000000001'
);

insert into public.sq8_squad_members (squad_id, user_id)
select
  'e2000000-0000-4000-8000-000000000001',
  ('e2000000-0000-4000-8000-00000000000' || n::text)::uuid
from generate_series(2, 8) as n;

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses
) values (
  'e2000000-0000-4000-8000-000000000001',
  'BUSY2345',
  'e2000000-0000-4000-8000-000000000001',
  now() + interval '1 day',
  1
);

select set_config('request.jwt.claim.sub', 'e2000000-0000-4000-8000-000000000009', false);
set role authenticated;

do $$
declare
  result jsonb;
begin
  result := public.sq8_join_with_code('BUSY2345');
  if result ->> 'error' is distinct from 'full' then
    raise exception 'full squad returned %', result;
  end if;
end $$;

reset role;
set role anon;

do $$
begin
  perform public.sq8_join_with_code('ABCD2345');
  raise exception 'anon join was accepted';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
