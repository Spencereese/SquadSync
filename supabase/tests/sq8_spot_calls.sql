-- Spot calls: membership, the five-minute window, starters, lock, and the cap.
-- Not the live project.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('c6000000-0000-4000-8000-000000000001', 'spot-owner@example.com'),
  ('c6000000-0000-4000-8000-000000000002', 'spot-starter@example.com'),
  ('c6000000-0000-4000-8000-000000000003', 'spot-late@example.com'),
  ('c6000000-0000-4000-8000-000000000004', 'spot-promoted@example.com'),
  ('c6000000-0000-4000-8000-000000000005', 'spot-later@example.com'),
  ('c6000000-0000-4000-8000-000000000006', 'spot-expired-later@example.com');

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
  ),
  (
    'c6100000-0000-4000-8000-000000000001',
    'c6000000-0000-4000-8000-000000000004'
  ),
  (
    'c6100000-0000-4000-8000-000000000001',
    'c6000000-0000-4000-8000-000000000005'
  ),
  (
    'c6100000-0000-4000-8000-000000000001',
    'c6000000-0000-4000-8000-000000000006'
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
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000005',
  false
);
set role authenticated;

insert into public.sq8_check_ins (user_id, squad_id, kind, until_at)
values (
  'c6000000-0000-4000-8000-000000000005',
  'c6100000-0000-4000-8000-000000000001',
  'available_later',
  now() + interval '2 hours'
);

reset role;
set session_replication_role = replica;
insert into public.sq8_check_ins (user_id, squad_id, kind, checked_at, until_at)
values
  (
    'c6000000-0000-4000-8000-000000000004',
    'c6100000-0000-4000-8000-000000000001',
    'available_later',
    now() - interval '2 hours',
    now() - interval '30 minutes'
  ),
  (
    'c6000000-0000-4000-8000-000000000006',
    'c6100000-0000-4000-8000-000000000001',
    'available_later',
    now() - interval '4 hours',
    now() - interval '2 hours'
  );
set session_replication_role = origin;
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

  select rsvps.starter
    into starter
  from public.sq8_spot_rsvps as rsvps
  join public.sq8_spot_calls as calls on calls.id = rsvps.call_id
  where rsvps.user_id = 'c6000000-0000-4000-8000-000000000004'
    and calls.closed_at is null;
  if starter is not true then
    raise exception 'a promoted later check-in was not a starter';
  end if;

  if exists (
    select 1
    from public.sq8_spot_rsvps as rsvps
    join public.sq8_spot_calls as calls on calls.id = rsvps.call_id
    where calls.closed_at is null
      and rsvps.user_id in (
        'c6000000-0000-4000-8000-000000000005',
        'c6000000-0000-4000-8000-000000000006'
      )
  ) then
    raise exception 'a later or expired check-in was seated as a starter';
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
  begin
    perform public.sq8_end_spot(call_id);
    raise exception 'a member ended someone else''s call';
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

select public.sq8_end_spot(id)
from public.sq8_spot_calls
where squad_id = 'c6100000-0000-4000-8000-000000000001'
  and closed_at is null;

do $$
declare
  spot_status text;
begin
  select status
    into spot_status
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and locked_at is not null;
  if spot_status is distinct from 'ended' then
    raise exception 'ended call status was %', spot_status;
  end if;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000003',
  false
);
set role authenticated;

select public.sq8_call_spot(
  'c6100000-0000-4000-8000-000000000001',
  'Halo',
  now()
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000001',
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
    perform public.sq8_cancel_spot(call_id);
    raise exception 'the owner canceled someone else''s call';
  exception
    when insufficient_privilege then
      null;
  end;
end $$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000003',
  false
);
set role authenticated;

select public.sq8_cancel_spot(id)
from public.sq8_spot_calls
where squad_id = 'c6100000-0000-4000-8000-000000000001'
  and closed_at is null;

do $$
declare
  spot_status text;
begin
  select status
    into spot_status
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and caller_id = 'c6000000-0000-4000-8000-000000000003'
  order by called_at desc
  limit 1;
  if spot_status is distinct from 'cancelled' then
    raise exception 'canceled call status was %', spot_status;
  end if;
end $$;

select public.sq8_call_spot(
  'c6100000-0000-4000-8000-000000000001',
  'Halo',
  now()
);

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
    perform public.sq8_cancel_spot(call_id);
    raise exception 'a locked call was canceled';
  exception
    when sqlstate 'P0001' then
      null;
  end;
end $$;

reset role;

update public.sq8_spot_calls
set locked_at = now() - interval '6 hours' - interval '1 second'
where squad_id = 'c6100000-0000-4000-8000-000000000001'
  and closed_at is null;

select set_config(
  'request.jwt.claim.sub',
  'c6000000-0000-4000-8000-000000000003',
  false
);
set role authenticated;

select public.sq8_call_spot(
  'c6100000-0000-4000-8000-000000000001',
  'Next',
  now()
);

do $$
declare
  ended text;
  live text;
begin
  select status
    into ended
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and game = 'Halo'
    and caller_id = 'c6000000-0000-4000-8000-000000000003'
    and locked_at is not null;
  if ended is distinct from 'ended' then
    raise exception 'a locked call past 6 hours stayed %', ended;
  end if;
  select status
    into live
  from public.sq8_spot_calls
  where squad_id = 'c6100000-0000-4000-8000-000000000001'
    and closed_at is null;
  if live is distinct from 'open' then
    raise exception 'the next call was %', live;
  end if;
end $$;

reset role;

do $$
declare
  wrapper text;
  impl text;
begin
  foreach wrapper in array array[
    'public.sq8_call_spot(uuid, text, timestamptz)',
    'public.sq8_rsvp_spot(uuid, text)',
    'public.sq8_lock_spot(uuid)',
    'public.sq8_end_spot(uuid)',
    'public.sq8_cancel_spot(uuid)'
  ]
  loop
    if has_function_privilege('anon', wrapper, 'execute')
       or has_function_privilege('public', wrapper, 'execute') then
      raise exception 'anon or public can execute %', wrapper;
    end if;
    if not has_function_privilege('authenticated', wrapper, 'execute') then
      raise exception 'authenticated cannot execute %', wrapper;
    end if;
  end loop;

  foreach impl in array array[
    'sq8.call_spot(uuid, text, timestamptz)',
    'sq8.rsvp_spot(uuid, text)',
    'sq8.lock_spot(uuid)',
    'sq8.end_spot(uuid)',
    'sq8.cancel_spot(uuid)'
  ]
  loop
    if has_function_privilege('anon', impl, 'execute')
       or has_function_privilege('public', impl, 'execute')
       or has_function_privilege('authenticated', impl, 'execute') then
      raise exception 'a client role can execute %', impl;
    end if;
  end loop;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_spot_calls'
  ) or not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_spot_rsvps'
  ) then
    raise exception 'spot tables are missing from supabase_realtime';
  end if;
end $$;
