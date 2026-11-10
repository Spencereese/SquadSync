-- Spot calls: membership, the five-minute window, starters, lock, and the cap.
-- Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('c6000000-0000-4000-8000-000000000001', 'spot-owner@example.com'),
  ('c6000000-0000-4000-8000-000000000002', 'spot-starter@example.com'),
  ('c6000000-0000-4000-8000-000000000003', 'spot-late@example.com');

insert into public.sq8_squads (id, owner_id)
values (
  'c6100000-0000-4000-8000-000000000001',
  'c6000000-0000-4000-8000-000000000001'
);

insert into public.sq8_squad_members (squad_id, user_id) values
  (
    'c6100000-0000-4000-8000-000000000001',
    'c6000000-0000-4000-8000-000000000002'
  ),
  (
    'c6100000-0000-4000-8000-000000000001',
    'c6000000-0000-4000-8000-000000000003'
  );

select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000002',
  false
);
set role authenticated;

insert into public.sq8_check_ins (user_id, squad_id, kind, until_at)
values (
  'c6000000-0000-4000-8000-000000000002',
  'c6100000-0000-4000-8000-000000000001',
  'available_now',
  now() + interval '30 minutes'
);

reset role;
set role anon;

do $$
begin
  perform public.sq8_call_spot(
    'c6100000-0000-4000-8000-000000000001',
    'Halo',
    now()
  );
  raise exception 'anon called a spot';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

select public.sq8_call_spot(
  'c6100000-0000-4000-8000-000000000001',
  'Halo',
  now() + interval '10 minutes'
);

do $$
declare
  window_seconds numeric;
  starter boolean;
  caller_starter boolean;
begin
  select extract(epoch from (join_until - called_at))
    into window_seconds
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and closed_at is null;
  if window_seconds < 299 or window_seconds > 301 then
    raise exception 'join window was % seconds', window_seconds;
  end if;

  select rsvps.starter
    into starter
  from public.sq8_spot_rsvps as rsvps
  join public.sq8_spot_calls as calls on calls.id = rsvps.call_id
  where rsvps.user_id = 'c6000000-0000-4000-8000-000000000002'
    and calls.closed_at is null;
  if starter is not true then
    raise exception 'in-game member was not a starter';
  end if;

  select rsvps.starter
    into caller_starter
  from public.sq8_spot_rsvps as rsvps
  join public.sq8_spot_calls as calls on calls.id = rsvps.call_id
  where rsvps.user_id = 'c6000000-0000-4000-8000-000000000001'
    and calls.closed_at is null;
  if caller_starter is not false then
    raise exception 'caller was marked a starter';
  end if;
end $$;

do $$
begin
  perform public.sq8_call_spot(
    'c6100000-0000-4000-8000-000000000001',
    'Halo',
    now()
  );
  raise exception 'second call replaced an open one';
exception
  when sqlstate 'P0001' then
    null;
end $$;

reset role;

update public.sq8_spot_calls
set join_until = now() - interval '1 second'
where squad_id = 'c6100000-0000-4000-8000-000000000001'
  and closed_at is null;

select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000003',
  false
);
set role authenticated;

do $$
declare
  call_id uuid;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and closed_at is null;
  begin
    perform public.sq8_rsvp_spot(call_id, 'in');
    raise exception 'late join was accepted';
  exception
    when sqlstate 'P0001' then
      null;
  end;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000002',
  false
);
set role authenticated;

do $$
declare
  call_id uuid;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and closed_at is null;
  perform public.sq8_rsvp_spot(call_id, 'in');
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000003',
  false
);
set role authenticated;

do $$
declare
  call_id uuid;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and closed_at is null;
  begin
    perform public.sq8_lock_spot(call_id);
    raise exception 'a member locked someone else''s call';
  exception
    when insufficient_privilege then
      null;
  end;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000001',
  false
);
set role authenticated;

select public.sq8_lock_spot(id)
from public.sq8_spot_calls
where squad_id = 'c6100000-0000-4000-8000-000000000001'
  and closed_at is null;

do $$
declare
  call_id uuid;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and closed_at is null;
  begin
    perform public.sq8_rsvp_spot(call_id, 'out');
    raise exception 'rsvp changed a locked call';
  exception
    when sqlstate 'P0001' then
      null;
  end;
end $$;

reset role;
