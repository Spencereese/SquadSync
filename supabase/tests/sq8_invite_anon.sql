-- anon cannot call the invite RPCs. authenticated still can.
-- Not for the live project.
\set ON_ERROR_STOP on

grant execute on function public.sq8_join_with_code(text) to public, anon;
grant execute on function public.sq8_create_invite() to public, anon;
grant execute on function sq8.join_with_code(text) to public, anon;
grant execute on function sq8.create_invite() to public, anon;

do $$
begin
  if not has_function_privilege(
    'anon', 'public.sq8_join_with_code(text)', 'execute'
  ) then
    raise exception 'the anon grant did not stick before the revoke';
  end if;
end $$;

\ir ../migrations/20261109_0010_revoke_anon_invite_rpcs.sql

do $$
begin
  if has_function_privilege(
    'anon', 'public.sq8_join_with_code(text)', 'execute'
  ) then
    raise exception 'anon can still execute public.sq8_join_with_code';
  end if;
  if has_function_privilege(
    'anon', 'public.sq8_create_invite()', 'execute'
  ) then
    raise exception 'anon can still execute public.sq8_create_invite';
  end if;
  if has_function_privilege(
    'anon', 'sq8.join_with_code(text)', 'execute'
  ) then
    raise exception 'anon can still execute sq8.join_with_code';
  end if;
  if has_function_privilege(
    'anon', 'sq8.create_invite()', 'execute'
  ) then
    raise exception 'anon can still execute sq8.create_invite';
  end if;
  if not has_function_privilege(
    'authenticated', 'public.sq8_join_with_code(text)', 'execute'
  ) then
    raise exception 'authenticated lost public.sq8_join_with_code';
  end if;
  if not has_function_privilege(
    'authenticated', 'public.sq8_create_invite()', 'execute'
  ) then
    raise exception 'authenticated lost public.sq8_create_invite';
  end if;
  if has_function_privilege(
    'authenticated', 'sq8.join_with_code(text)', 'execute'
  ) then
    raise exception 'authenticated can call sq8.join_with_code';
  end if;
  if has_function_privilege(
    'authenticated', 'sq8.create_invite()', 'execute'
  ) then
    raise exception 'authenticated can call sq8.create_invite';
  end if;
end $$;

set role anon;

do $$
begin
  perform public.sq8_join_with_code('ZZZZZZZZ');
  raise exception 'anon was allowed to join';
exception
  when insufficient_privilege then
    null;
end $$;

do $$
begin
  perform public.sq8_create_invite();
  raise exception 'anon was allowed to create an invite';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;

select set_config(
  'request.jwt.claim.sub',
  'e0000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

do $$
declare
  body jsonb;
begin
  select public.sq8_join_with_code('ZZZZZZZZ') into body;
  if body->>'ok' <> 'false' or body->>'error' <> 'invalid' then
    raise exception 'authenticated join did not stay callable: %', body;
  end if;
end $$;

reset role;
