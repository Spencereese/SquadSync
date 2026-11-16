-- Local throwaway only. Apply 20261113_0018_squad_name.sql and
-- 20261116_0021_rename_squad.sql first.
-- Not listed in supabase/tests/run.sh. Do not run this on the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('d8000000-0000-4000-8000-000000000001', 'rename-owner@example.com'),
  ('d8000000-0000-4000-8000-000000000002', 'rename-member@example.com');

insert into public.sq8_squads (id, owner_id, name)
values (
  'd8100000-0000-4000-8000-000000000001',
  'd8000000-0000-4000-8000-000000000001',
  null
);

insert into public.sq8_squad_members (squad_id, user_id)
values (
  'd8100000-0000-4000-8000-000000000001',
  'd8000000-0000-4000-8000-000000000002'
);

select set_config('request.jwt.claim.sub', 'd8000000-0000-4000-8000-000000000002', false);
set role authenticated;

do $$
declare
  result jsonb;
begin
  result := public.sq8_rename_squad(
    'd8100000-0000-4000-8000-000000000001',
    'Night'
  );
  if result ->> 'error' is distinct from 'not_owner' then
    raise exception 'a member renamed the squad: %', result;
  end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'd8000000-0000-4000-8000-000000000001', false);
set role authenticated;

do $$
declare
  result jsonb;
  stored text;
begin
  result := public.sq8_rename_squad(
    'd8100000-0000-4000-8000-000000000001',
    '  Night  '
  );
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'owner rename failed: %', result;
  end if;
  select name into stored
  from public.sq8_squads
  where id = 'd8100000-0000-4000-8000-000000000001';
  if stored is distinct from 'Night' then
    raise exception 'stored name was %', stored;
  end if;

  result := public.sq8_rename_squad(
    'd8100000-0000-4000-8000-000000000001',
    repeat('a', 41)
  );
  if result ->> 'error' is distinct from 'name_length' then
    raise exception 'a long name was accepted: %', result;
  end if;
  select name into stored
  from public.sq8_squads
  where id = 'd8100000-0000-4000-8000-000000000001';
  if stored is distinct from 'Night' then
    raise exception 'a rejected rename changed the name to %', stored;
  end if;

  result := public.sq8_rename_squad(
    'd8100000-0000-4000-8000-000000000001',
    '   '
  );
  if result ->> 'ok' is distinct from 'true' then
    raise exception 'clearing the name failed: %', result;
  end if;
  select name into stored
  from public.sq8_squads
  where id = 'd8100000-0000-4000-8000-000000000001';
  if stored is not null then
    raise exception 'cleared name was %', stored;
  end if;
end $$;

reset role;

do $$
declare
  allowed boolean;
begin
  select has_function_privilege('anon', 'public.sq8_rename_squad(uuid, text)', 'execute')
    into allowed;
  if allowed then
    raise exception 'anon can rename a squad';
  end if;
  select has_function_privilege('authenticated', 'public.sq8_rename_squad(uuid, text)', 'execute')
    into allowed;
  if not allowed then
    raise exception 'authenticated cannot rename a squad';
  end if;
  select has_function_privilege('authenticated', 'sq8.rename_squad(uuid, text)', 'execute')
    into allowed;
  if allowed then
    raise exception 'authenticated can call the inner rename function';
  end if;
end $$;
