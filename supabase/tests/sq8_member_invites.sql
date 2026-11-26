-- 0029: any member gets the group's invite; members share one code instead of
-- cancelling each other's; a code with a day or less left is replaced; the
-- 8-person cap and owner-only removal are unchanged. Not the live project.
\set ON_ERROR_STOP on

do $$
begin
  if not has_function_privilege('authenticated', 'public.sq8_member_invite()', 'EXECUTE') then
    raise exception 'authenticated cannot get a member invite';
  end if;
  if has_function_privilege('anon', 'public.sq8_member_invite()', 'EXECUTE')
    or has_function_privilege('authenticated', 'sq8.member_invite()', 'EXECUTE') then
    raise exception 'member invite is callable by anon or directly';
  end if;
end $$;

insert into auth.users (id, email)
select ('ea000000-0000-4000-8000-00000000000' || n::text)::uuid, 'zinvite-' || n::text || '@example.com'
from generate_series(1, 4) as n;
insert into public.sq8_squads (id, owner_id)
values ('ea100000-0000-4000-8000-000000000001', 'ea000000-0000-4000-8000-000000000001');
insert into public.sq8_squad_members (squad_id, user_id) values
  ('ea100000-0000-4000-8000-000000000001', 'ea000000-0000-4000-8000-000000000002'),
  ('ea100000-0000-4000-8000-000000000001', 'ea000000-0000-4000-8000-000000000003');

set role authenticated;

-- Not in a group: refused with a code the app knows.
select set_config('request.jwt.claim.sub', 'ea000000-0000-4000-8000-000000000004', false);
do $$ begin
  if public.sq8_member_invite() ->> 'error' is distinct from 'not_member' then
    raise exception 'a non-member got an invite';
  end if;
end $$;

-- A member (not the owner) gets one; another member gets the same code.
select set_config('request.jwt.claim.sub', 'ea000000-0000-4000-8000-000000000002', false);
select public.sq8_member_invite() ->> 'code' as first_code \gset
select set_config('t.first_code', :'first_code', false);
select set_config('request.jwt.claim.sub', 'ea000000-0000-4000-8000-000000000003', false);
do $$
declare
  answer jsonb := public.sq8_member_invite();
begin
  if not (answer ->> 'ok')::boolean then
    raise exception 'member invite failed: %', answer;
  end if;
  if answer ->> 'code' <> current_setting('t.first_code') then
    raise exception 'a second member cancelled the first link';
  end if;
  if answer ->> 'squad_id' <> 'ea100000-0000-4000-8000-000000000001' then
    raise exception 'wrong group on the invite';
  end if;
end $$;

-- The code joins someone (4) the usual way.
select set_config('request.jwt.claim.sub', 'ea000000-0000-4000-8000-000000000004', false);
do $$ begin
  if not (public.sq8_join_with_code(current_setting('t.first_code')) ->> 'ok')::boolean then
    raise exception 'the member invite did not join';
  end if;
end $$;

-- Removing people is still owner-only: a member's delete touches nothing.
select set_config('request.jwt.claim.sub', 'ea000000-0000-4000-8000-000000000002', false);
delete from public.sq8_squad_members
where squad_id = 'ea100000-0000-4000-8000-000000000001'
  and user_id = 'ea000000-0000-4000-8000-000000000003';
reset role;
do $$ begin
  if not exists (
    select 1 from public.sq8_squad_members
    where squad_id = 'ea100000-0000-4000-8000-000000000001'
      and user_id = 'ea000000-0000-4000-8000-000000000003'
  ) then
    raise exception 'a member removed someone';
  end if;
end $$;

-- A code with less than a day left is replaced, and the old one stops working.
update public.sq8_invites set expires_at = now() + interval '2 hours'
where code = current_setting('t.first_code');
set role authenticated;
select set_config('request.jwt.claim.sub', 'ea000000-0000-4000-8000-000000000003', false);
do $$
declare
  answer jsonb := public.sq8_member_invite();
begin
  if answer ->> 'code' = current_setting('t.first_code') then
    raise exception 'an almost-expired code was handed out again';
  end if;
end $$;
reset role;
do $$ begin
  if (select revoked_at from public.sq8_invites where code = current_setting('t.first_code')) is null then
    raise exception 'the replaced code was not revoked';
  end if;
  if (select count(*) from public.sq8_invites
      where squad_id = 'ea100000-0000-4000-8000-000000000001' and revoked_at is null) <> 1 then
    raise exception 'more than one live invite';
  end if;
end $$;

select 'sq8 member invites ok';
