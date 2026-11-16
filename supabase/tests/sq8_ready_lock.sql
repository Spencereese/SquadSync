-- Local throwaway only. Apply 20261116_0020_ready_lock.sql first.
-- Not listed in supabase/tests/run.sh. Do not run this on the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('d7000000-0000-4000-8000-000000000001', 'ready-owner@example.com'),
  ('d7000000-0000-4000-8000-000000000002', 'ready-friend@example.com'),
  ('d7000000-0000-4000-8000-000000000003', 'ready-stranger@example.com');

insert into public.sq8_squads (id, owner_id)
values (
  'd7100000-0000-4000-8000-000000000001',
  'd7000000-0000-4000-8000-000000000001'
);

insert into public.sq8_squad_members (squad_id, user_id)
values (
  'd7100000-0000-4000-8000-000000000001',
  'd7000000-0000-4000-8000-000000000002'
);

select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000001', false);
set role authenticated;

select public.sq8_call_spot(
  'd7100000-0000-4000-8000-000000000001',
  'Warzone',
  now()
);

reset role;
select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000002', false);
set role authenticated;

do $$
declare
  call_id uuid;
  ready boolean;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'd7100000-0000-4000-8000-000000000001'
    and closed_at is null;

  perform public.sq8_rsvp_spot(call_id, 'in');
  perform public.sq8_set_spot_ready(call_id, true);
  perform public.sq8_rsvp_spot(call_id, 'in');

  select rsvps.ready into ready
  from public.sq8_spot_rsvps as rsvps
  where rsvps.call_id = call_id
    and rsvps.user_id = 'd7000000-0000-4000-8000-000000000002';
  if ready is not true then
    raise exception 'answering in again cleared Ready';
  end if;

  perform public.sq8_rsvp_spot(call_id, 'out');
  perform public.sq8_rsvp_spot(call_id, 'in');

  select rsvps.ready into ready
  from public.sq8_spot_rsvps as rsvps
  where rsvps.call_id = call_id
    and rsvps.user_id = 'd7000000-0000-4000-8000-000000000002';
  if ready is not false then
    raise exception 'out then in kept Ready';
  end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000001', false);
set role authenticated;

do $$
declare
  call_id uuid;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'd7100000-0000-4000-8000-000000000001'
    and closed_at is null;
  perform public.sq8_set_spot_ready(call_id, true);
  begin
    perform public.sq8_lock_spot(call_id);
    raise exception 'old lock path ignored Ready';
  exception
    when sqlstate 'P0001' then
      if sqlerrm not like '%spot_not_ready%' then
        raise;
      end if;
  end;
end $$;

reset role;

delete from public.sq8_squad_members
where squad_id = 'd7100000-0000-4000-8000-000000000001'
  and user_id = 'd7000000-0000-4000-8000-000000000002';

insert into public.sq8_spot_rsvps (call_id, user_id, response, starter, ready)
select calls.id, 'd7000000-0000-4000-8000-000000000003', 'in', false, false
from public.sq8_spot_calls as calls
where calls.squad_id = 'd7100000-0000-4000-8000-000000000001'
  and calls.closed_at is null;

do $$
declare
  call_id uuid;
  left_behind integer;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'd7100000-0000-4000-8000-000000000001'
    and closed_at is null;

  select count(*) into left_behind
  from public.sq8_spot_rsvps
  where call_id = call_id
    and user_id = 'd7000000-0000-4000-8000-000000000002';
  if left_behind <> 0 then
    raise exception 'leaving kept an open RSVP';
  end if;
end $$;

insert into public.sq8_squad_members (squad_id, user_id)
values (
  'd7100000-0000-4000-8000-000000000001',
  'd7000000-0000-4000-8000-000000000002'
);

select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000002', false);
set role authenticated;

do $$
declare
  call_id uuid;
  ready boolean;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'd7100000-0000-4000-8000-000000000001'
    and closed_at is null;
  perform public.sq8_rsvp_spot(call_id, 'in');
  select rsvps.ready into ready
  from public.sq8_spot_rsvps as rsvps
  where rsvps.call_id = call_id
    and rsvps.user_id = 'd7000000-0000-4000-8000-000000000002';
  if ready is not false then
    raise exception 'rejoin restored Ready';
  end if;
end $$;

reset role;

delete from public.sq8_squad_members
where squad_id = 'd7100000-0000-4000-8000-000000000001'
  and user_id = 'd7000000-0000-4000-8000-000000000002';

select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000001', false);
set role authenticated;

select public.sq8_lock_spot(id)
from public.sq8_spot_calls
where squad_id = 'd7100000-0000-4000-8000-000000000001'
  and closed_at is null;

reset role;

do $$
declare
  spot_status text;
begin
  select status into spot_status
  from public.sq8_spot_calls
  where squad_id = 'd7100000-0000-4000-8000-000000000001'
    and closed_at is null;
  if spot_status is distinct from 'locked' then
    raise exception 'a leaver or a non-member blocked lock, status %', spot_status;
  end if;
end $$;

insert into public.sq8_squad_members (squad_id, user_id)
values (
  'd7100000-0000-4000-8000-000000000001',
  'd7000000-0000-4000-8000-000000000002'
);

select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000001', false);
set role authenticated;

select public.sq8_end_spot(id)
from public.sq8_spot_calls
where squad_id = 'd7100000-0000-4000-8000-000000000001'
  and status = 'locked';

reset role;
select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000001', false);
set role authenticated;

select public.sq8_call_spot(
  'd7100000-0000-4000-8000-000000000001',
  'Halo',
  now()
);

reset role;

update public.sq8_spot_calls
set join_until = now() - interval '1 second'
where squad_id = 'd7100000-0000-4000-8000-000000000001'
  and closed_at is null;

update public.sq8_spot_rsvps as rsvps
set starter = true,
    response = 'out'
from public.sq8_spot_calls as calls
where rsvps.call_id = calls.id
  and calls.squad_id = 'd7100000-0000-4000-8000-000000000001'
  and calls.closed_at is null
  and rsvps.user_id = 'd7000000-0000-4000-8000-000000000001';

select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000001', false);
set role authenticated;

do $$
declare
  payload jsonb;
begin
  payload := public.sq8_read_open_spot('d7100000-0000-4000-8000-000000000001');
  if payload -> 'call' ->> 'status' is distinct from 'expired' then
    raise exception 'read did not stamp expiry, got %', payload -> 'call' ->> 'status';
  end if;
end $$;

do $$
declare
  call_id uuid;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'd7100000-0000-4000-8000-000000000001'
    and closed_at is null;
  perform public.sq8_rsvp_spot(call_id, 'in');
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'd7000000-0000-4000-8000-000000000002', false);
set role authenticated;

do $$
declare
  call_id uuid;
begin
  select id into call_id
  from public.sq8_spot_calls
  where squad_id = 'd7100000-0000-4000-8000-000000000001'
    and closed_at is null;
  begin
    perform public.sq8_rsvp_spot(call_id, 'in');
    raise exception 'a non-starter joined after expiry';
  exception
    when sqlstate 'P0001' then
      if sqlerrm not like '%spot_join_closed%' then
        raise;
      end if;
  end;
end $$;

reset role;
