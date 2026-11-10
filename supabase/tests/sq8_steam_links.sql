-- Steam links stay on the owner's row. Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('c9000000-0000-4000-8000-000000000001', 'steam-owner@example.com'),
  ('c9000000-0000-4000-8000-000000000002', 'steam-friend@example.com');

insert into public.sq8_squads (id, owner_id)
values (
  'c9100000-0000-4000-8000-000000000001',
  'c9000000-0000-4000-8000-000000000001'
);

insert into public.sq8_squad_members (squad_id, user_id)
values (
  'c9100000-0000-4000-8000-000000000001',
  'c9000000-0000-4000-8000-000000000002'
);

select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

insert into public.sq8_steam_links (user_id, steam_id)
values (
  'c9000000-0000-4000-8000-000000000001',
  '76561198000000001'
);

do $$
begin
  insert into public.sq8_steam_links (user_id, steam_id)
  values (
    'c9000000-0000-4000-8000-000000000001',
    'not-a-steam-id'
  );
  raise exception 'a short steam id was stored';
exception
  when check_violation then
    null;
end $$;

do $$
begin
  insert into public.sq8_steam_links (user_id, steam_id)
  values (
    'c9000000-0000-4000-8000-000000000002',
    '76561198000000002'
  );
  raise exception 'wrote a steam id for someone else';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
set role anon;

do $$
begin
  perform 1 from public.sq8_steam_links;
  raise exception 'anon read steam links';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000002',
  false
);
set role authenticated;

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_steam_links;
  if n is distinct from 0 then
    raise exception 'a squad mate saw % steam ids', n;
  end if;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

update public.sq8_steam_links
set steam_id = '76561198000000009'
where user_id = 'c9000000-0000-4000-8000-000000000001';

delete from public.sq8_steam_links
where user_id = 'c9000000-0000-4000-8000-000000000001';

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_steam_links;
  if n is distinct from 0 then
    raise exception 'unlink left % rows', n;
  end if;
end $$;

reset role;
