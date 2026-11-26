-- 0028 Game on: start, cap of 2, join until full, leave, Ready, close by the
-- starter only, close when everyone leaves, 3-hour idle expiry, old spot
-- calls untouched, privileges. Local throwaway only, never the live project.
\set ON_ERROR_STOP on

create or replace function pg_temp.expect_error(statement text, wanted text)
returns void
language plpgsql
as $$
declare
  failed text;
begin
  begin
    execute statement;
  exception
    when others then
      failed := sqlerrm;
  end;
  if failed is null then
    raise exception 'expected % from: %', wanted, statement;
  end if;
  if failed not like '%' || wanted || '%' then
    raise exception 'expected % from: %, got %', wanted, statement, failed;
  end if;
end;
$$;

create or replace function pg_temp.as_user(id text)
returns void
language sql
as $$ select set_config('request.jwt.claim.sub', id, false); $$;

-- Privileges: wrappers for authenticated only; implementations for nobody.
do $$
begin
  if not has_function_privilege('authenticated', 'public.sq8_start_game_on(uuid, text, integer)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.sq8_join_game_on(uuid)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.sq8_leave_game_on(uuid)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.sq8_set_game_on_ready(uuid, boolean)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.sq8_close_game_on(uuid)', 'EXECUTE') then
    raise exception 'authenticated is missing a Game on wrapper';
  end if;
  if has_function_privilege('anon', 'public.sq8_start_game_on(uuid, text, integer)', 'EXECUTE')
    or has_function_privilege('anon', 'public.sq8_join_game_on(uuid)', 'EXECUTE')
    or has_function_privilege('anon', 'public.sq8_close_game_on(uuid)', 'EXECUTE') then
    raise exception 'anon can call a Game on wrapper';
  end if;
  if has_function_privilege('authenticated', 'public.sq8_game_on_push_context(uuid)', 'EXECUTE')
    or has_function_privilege('anon', 'public.sq8_game_on_push_context(uuid)', 'EXECUTE') then
    raise exception 'the push context is callable by a client';
  end if;
  if has_function_privilege('authenticated', 'sq8.start_game_on(uuid, text, integer)', 'EXECUTE')
    or has_function_privilege('authenticated', 'sq8.sweep_game_ons(uuid)', 'EXECUTE')
    or has_function_privilege('authenticated', 'sq8.lock_game_on(uuid)', 'EXECUTE') then
    raise exception 'authenticated can call a Game on implementation directly';
  end if;
end $$;

insert into auth.users (id, email)
select ('e8000000-0000-4000-8000-00000000000' || n::text)::uuid, 'gameon-' || n::text || '@example.com'
from generate_series(1, 6) as n;
insert into public.sq8_profiles (id, display_name)
select id, 'Player ' || right(id::text, 1) from auth.users where email like 'gameon-%'
on conflict (id) do update set display_name = excluded.display_name;

-- Group A: 1 (owner), 2, 3, 4. Group B: 5 (owner). 6 is in no group.
insert into public.sq8_squads (id, owner_id) values
  ('e8100000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000001'),
  ('e8100000-0000-4000-8000-000000000002', 'e8000000-0000-4000-8000-000000000005');
insert into public.sq8_squad_members (squad_id, user_id) values
  ('e8100000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000002'),
  ('e8100000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000003'),
  ('e8100000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000004');

set role authenticated;

-- Bad input and outsiders.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000002');
select pg_temp.expect_error($q$select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', '  ', 1)$q$, 'game_on_game_blank');
select pg_temp.expect_error($q$select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', repeat('x', 61), 1)$q$, 'game_on_game_long');
select pg_temp.expect_error($q$select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Warzone', 0)$q$, 'game_on_need_range');
select pg_temp.expect_error($q$select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Warzone', 8)$q$, 'game_on_need_range');
select pg_temp.as_user('e8000000-0000-4000-8000-000000000005');
select pg_temp.expect_error($q$select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Warzone', 1)$q$, 'game_on_not_member');
select pg_temp.as_user('');
select pg_temp.expect_error($q$select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Warzone', 1)$q$, 'game_on_signed_out');

-- A member (not the owner) starts "Warzone, need 1": 2 seats, starter in.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000002');
select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', ' Warzone ', 1) as first_id \gset
select set_config('t.first_id', :'first_id', false);

do $$
declare
  row public.sq8_spot_calls%rowtype;
begin
  select * into row from public.sq8_spot_calls where id = current_setting('t.first_id')::uuid;
  if row.kind <> 'game_on' or row.seat_target <> 2 or row.game <> 'Warzone'
    or row.status <> 'open' or row.closed_at is not null then
    raise exception 'start stored the wrong row: %', row;
  end if;
  if row.join_until < now() + interval '2 hours 59 minutes' then
    raise exception 'idle deadline is not 3 hours out';
  end if;
  if (select count(*) from public.sq8_spot_rsvps
      where call_id = row.id and user_id = 'e8000000-0000-4000-8000-000000000002'
        and response = 'in' and starter) <> 1 then
    raise exception 'the starter is not in';
  end if;
end $$;

-- An outsider can't see it; a member can.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000005');
do $$ begin
  if exists (select 1 from public.sq8_spot_calls where kind = 'game_on') then
    raise exception 'another group can read the Game on';
  end if;
end $$;
select pg_temp.expect_error(format('select public.sq8_join_game_on(%L)', :'first_id'), 'game_on_not_member');

-- 3 joins and fills it; 4 is told it's full. Joining twice is fine.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000003');
select public.sq8_join_game_on(:'first_id');
select public.sq8_join_game_on(:'first_id');
select pg_temp.as_user('e8000000-0000-4000-8000-000000000004');
select pg_temp.expect_error(format('select public.sq8_join_game_on(%L)', :'first_id'), 'game_on_full');

-- Ready: only someone who is in.
select pg_temp.expect_error(format('select public.sq8_set_game_on_ready(%L, true)', :'first_id'), 'game_on_not_in');
select pg_temp.as_user('e8000000-0000-4000-8000-000000000003');
select public.sq8_set_game_on_ready(:'first_id', true);
do $$ begin
  if not (select ready from public.sq8_spot_rsvps where call_id = current_setting('t.first_id')::uuid and user_id = 'e8000000-0000-4000-8000-000000000003') then
    raise exception 'Ready did not stick';
  end if;
end $$;

-- 3 leaves: a seat opens, 4 can join, and Ready resets on the way back in.
select public.sq8_leave_game_on(:'first_id');
select pg_temp.as_user('e8000000-0000-4000-8000-000000000004');
select public.sq8_join_game_on(:'first_id');
select pg_temp.as_user('e8000000-0000-4000-8000-000000000003');
select pg_temp.expect_error(format('select public.sq8_join_game_on(%L)', :'first_id'), 'game_on_full');

-- Only the starter closes it. The owner (1) can't.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000001');
select pg_temp.expect_error(format('select public.sq8_close_game_on(%L)', :'first_id'), 'game_on_not_starter');
select pg_temp.as_user('e8000000-0000-4000-8000-000000000004');
select pg_temp.expect_error(format('select public.sq8_close_game_on(%L)', :'first_id'), 'game_on_not_starter');

-- Cap: a second is fine, a third is refused while two are open.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000003');
select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Apex Legends', 2) as second_id \gset
select set_config('t.second_id', :'second_id', false);
select pg_temp.as_user('e8000000-0000-4000-8000-000000000001');
select pg_temp.expect_error($q$select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Halo', 1)$q$, 'game_on_cap');

-- The starter closes the first: it's ended, and a third can start.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000002');
select public.sq8_close_game_on(:'first_id');
select public.sq8_close_game_on(:'first_id');
select pg_temp.expect_error(format('select public.sq8_join_game_on(%L)', :'first_id'), 'game_on_closed');
do $$ begin
  if (select status from public.sq8_spot_calls where id = current_setting('t.first_id')::uuid) <> 'ended'
    or (select closed_at from public.sq8_spot_calls where id = current_setting('t.first_id')::uuid) is null then
    raise exception 'close did not end it';
  end if;
end $$;
select pg_temp.as_user('e8000000-0000-4000-8000-000000000001');
select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Halo', 1) as third_id \gset
select set_config('t.third_id', :'third_id', false);

-- Everyone leaving ends it: 3 started Apex alone and leaves.
select pg_temp.as_user('e8000000-0000-4000-8000-000000000003');
select public.sq8_leave_game_on(:'second_id');
select public.sq8_leave_game_on(:'second_id');
do $$ begin
  if (select status from public.sq8_spot_calls where id = current_setting('t.second_id')::uuid) <> 'ended' then
    raise exception 'the last one out did not end it';
  end if;
end $$;

reset role;

-- Idle: Halo's last activity was over 3 hours ago. The next start sweeps it.
update public.sq8_spot_calls
set join_until = now() - interval '1 minute'
where id = :'third_id';

set role authenticated;
select pg_temp.as_user('e8000000-0000-4000-8000-000000000004');
select pg_temp.expect_error(format('select public.sq8_join_game_on(%L)', :'third_id'), 'game_on_closed');
select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Rocket League', 3) as fourth_id \gset
select set_config('t.fourth_id', :'fourth_id', false);
select public.sq8_start_game_on('e8100000-0000-4000-8000-000000000001', 'Fortnite', 1) as fifth_id \gset
select set_config('t.fifth_id', :'fifth_id', false);
reset role;

-- The push context names the starter and how many are still needed.
do $$
declare
  ctx record;
begin
  select * into ctx from public.sq8_game_on_push_context(current_setting('t.fifth_id')::uuid);
  if ctx.caller_name <> 'Player 4' or ctx.game <> 'Fortnite' or ctx.need <> 1 or ctx.kind <> 'game_on' then
    raise exception 'push context is wrong: %', ctx;
  end if;
end $$;

do $$ begin
  if (select status from public.sq8_spot_calls where id = current_setting('t.third_id')::uuid) <> 'expired'
    or (select closed_at from public.sq8_spot_calls where id = current_setting('t.third_id')::uuid) is null then
    raise exception 'idle Game on was not expired';
  end if;
  if (select count(*) from public.sq8_spot_calls
      where squad_id = 'e8100000-0000-4000-8000-000000000001' and kind = 'game_on' and closed_at is null) <> 2 then
    raise exception 'cap of two did not hold after the sweep';
  end if;
end $$;

-- A member who leaves the group is dropped from the seats; when that empties
-- a Game on, the next action closes it.
delete from public.sq8_squad_members
where squad_id = 'e8100000-0000-4000-8000-000000000001'
  and user_id = 'e8000000-0000-4000-8000-000000000004';
set role authenticated;
select pg_temp.as_user('e8000000-0000-4000-8000-000000000002');
select pg_temp.expect_error(format('select public.sq8_join_game_on(%L)', :'fourth_id'), 'game_on_closed');
reset role;

-- Old-style spot calls still work next to Game ons: one live spot per group.
set role authenticated;
select pg_temp.as_user('e8000000-0000-4000-8000-000000000005');
select public.sq8_call_spot('e8100000-0000-4000-8000-000000000002'::uuid, 'Halo', now());
select pg_temp.expect_error($q$select public.sq8_call_spot('e8100000-0000-4000-8000-000000000002'::uuid, 'Halo', now())$q$, 'spot_already_open');
reset role;
do $$ begin
  if (select count(*) from public.sq8_spot_calls
      where squad_id = 'e8100000-0000-4000-8000-000000000002' and kind = 'spot' and closed_at is null) <> 1 then
    raise exception 'old spot call did not land as kind spot';
  end if;
end $$;

select 'sq8 game on ok';
