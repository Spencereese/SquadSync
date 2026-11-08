-- Own-profile recovery. Not for the live project.
\set ON_ERROR_STOP on

-- An auth user created before the profile trigger: drop the row the trigger made.
delete from public.sq8_profiles
where id = 'a0000000-0000-4000-8000-00000000000a';

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-00000000000a', false);
set role authenticated;

insert into public.sq8_profiles (id, display_name, default_game)
values (
  'a0000000-0000-4000-8000-00000000000a',
  'Outsider',
  'Call of Duty'
);

reset role;

insert into auth.users (id, email)
values ('a0000000-0000-4000-8000-00000000000b', 'other@example.com');
delete from public.sq8_profiles
where id = 'a0000000-0000-4000-8000-00000000000b';

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-00000000000a', false);
set role authenticated;

do $$
begin
  insert into public.sq8_profiles (id, display_name, default_game)
  values (
    'a0000000-0000-4000-8000-00000000000b',
    'Stolen',
    'Halo'
  );
  raise exception 'cross-user profile insert was accepted';
exception
  when insufficient_privilege then
    null;
end $$;

do $$
begin
  insert into public.sq8_profiles (id, display_name, default_game)
  values (
    'a0000000-0000-4000-8000-00000000000a',
    'Replaced',
    'Halo'
  );
  raise exception 'second profile insert was accepted';
exception
  when unique_violation then
    null;
end $$;

do $$
declare
  name text;
  game text;
begin
  select display_name, default_game into name, game
  from public.sq8_profiles
  where id = 'a0000000-0000-4000-8000-00000000000a';
  if name is distinct from 'Outsider' or game is distinct from 'Call of Duty' then
    raise exception 'existing profile was overwritten: % / %', name, game;
  end if;
end $$;

reset role;
set role anon;

do $$
begin
  insert into public.sq8_profiles (id, display_name, default_game)
  values (
    'a0000000-0000-4000-8000-00000000000a',
    'Anon',
    'Halo'
  );
  raise exception 'anon profile insert was accepted';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
