-- 0025 play-session guards: privileges, time window, fixed columns, final
-- cancel, RSVP only on a live session by a current member. Not the live project.
\set ON_ERROR_STOP on

-- Privileges: exactly what 0016 meant, nothing for anon.
do $$
begin
  if has_table_privilege('authenticated', 'public.sq8_sessions', 'TRUNCATE')
    or has_table_privilege('authenticated', 'public.sq8_sessions', 'DELETE')
    or has_table_privilege('authenticated', 'public.sq8_sessions', 'TRIGGER')
    or has_table_privilege('authenticated', 'public.sq8_sessions', 'REFERENCES')
    or has_table_privilege('authenticated', 'public.sq8_session_rsvps', 'TRUNCATE')
    or has_table_privilege('authenticated', 'public.sq8_session_rsvps', 'TRIGGER')
    or has_table_privilege('authenticated', 'public.sq8_session_rsvps', 'REFERENCES') then
    raise exception 'authenticated kept extra privileges on the session tables';
  end if;
  if not has_table_privilege('authenticated', 'public.sq8_sessions', 'SELECT')
    or not has_table_privilege('authenticated', 'public.sq8_sessions', 'INSERT')
    or not has_table_privilege('authenticated', 'public.sq8_sessions', 'UPDATE')
    or not has_table_privilege('authenticated', 'public.sq8_session_rsvps', 'SELECT')
    or not has_table_privilege('authenticated', 'public.sq8_session_rsvps', 'INSERT')
    or not has_table_privilege('authenticated', 'public.sq8_session_rsvps', 'UPDATE')
    or not has_table_privilege('authenticated', 'public.sq8_session_rsvps', 'DELETE') then
    raise exception 'authenticated lost a privilege 0016 granted';
  end if;
  if has_table_privilege('anon', 'public.sq8_sessions', 'SELECT')
    or has_table_privilege('anon', 'public.sq8_session_rsvps', 'SELECT') then
    raise exception 'anon can read the session tables';
  end if;
  if has_function_privilege('authenticated', 'sq8.guard_session_rsvp()', 'EXECUTE')
    or has_function_privilege('authenticated', 'sq8.guard_session_write()', 'EXECUTE') then
    raise exception 'authenticated can call a guard function directly';
  end if;
end $$;

insert into auth.users (id, email)
select
  ('dd000000-0000-4000-8000-00000000000' || n::text)::uuid,
  'guard-' || n::text || '@example.com'
from generate_series(1, 5) as n;

insert into public.sq8_squads (id, owner_id)
values
  ('dd100000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000001'),
  ('dd100000-0000-4000-8000-000000000002', 'dd000000-0000-4000-8000-000000000004');

insert into public.sq8_squad_members (squad_id, user_id)
values
  ('dd100000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000002'),
  ('dd100000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000003'),
  ('dd100000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000005');

-- A member (2) schedules tonight. created_at comes from the server.
select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000002', false);
set role authenticated;

insert into public.sq8_sessions (id, squad_id, creator_id, game, starts_at, note, created_at)
values (
  'dd200000-0000-4000-8000-000000000001',
  'dd100000-0000-4000-8000-000000000001',
  'dd000000-0000-4000-8000-000000000002',
  'Warzone',
  now() + interval '3 hours',
  'bring mics',
  timestamptz '2000-01-01 00:00:00+00'
);

do $$
begin
  if (select created_at from public.sq8_sessions where id = 'dd200000-0000-4000-8000-000000000001')
    < now() - interval '1 minute' then
    raise exception 'created_at was taken from the client';
  end if;
end $$;

-- Times: an hour ago and 61 days ahead are refused; a blank or 61-character game too.
do $$
declare
  attempt record;
begin
  for attempt in
    select * from (values
      ('session_time_past', now() - interval '1 hour', 'Warzone'),
      ('session_time_far', now() + interval '61 days', 'Warzone'),
      ('session_game_long', now() + interval '1 day', repeat('x', 61))
    ) as cases (expected, at, game)
  loop
    begin
      insert into public.sq8_sessions (squad_id, creator_id, game, starts_at)
      values (
        'dd100000-0000-4000-8000-000000000001',
        'dd000000-0000-4000-8000-000000000002',
        attempt.game,
        attempt.at
      );
      raise exception 'accepted a session that should fail with %', attempt.expected;
    exception
      when sqlstate 'P0001' then
        if sqlerrm is distinct from attempt.expected then
          raise exception 'expected %, got %', attempt.expected, sqlerrm;
        end if;
    end;
  end loop;

  begin
    insert into public.sq8_sessions (squad_id, creator_id, game, starts_at)
    values (
      'dd100000-0000-4000-8000-000000000001',
      'dd000000-0000-4000-8000-000000000002',
      '   ',
      now() + interval '1 day'
    );
    raise exception 'accepted a blank game';
  exception
    when check_violation then
      null;
  end;

  begin
    insert into public.sq8_sessions (squad_id, creator_id, game, starts_at, cancelled_at)
    values (
      'dd100000-0000-4000-8000-000000000001',
      'dd000000-0000-4000-8000-000000000002',
      'Apex',
      now() + interval '1 day',
      now()
    );
    raise exception 'accepted a session born cancelled';
  exception
    when sqlstate 'P0001' then
      if sqlerrm is distinct from 'session_cancelled' then
        raise exception 'expected session_cancelled, got %', sqlerrm;
      end if;
  end;
end $$;

-- A session in another squad is refused by 0016's RLS.
do $$
begin
  insert into public.sq8_sessions (squad_id, creator_id, game, starts_at)
  values (
    'dd100000-0000-4000-8000-000000000002',
    'dd000000-0000-4000-8000-000000000002',
    'Warzone',
    now() + interval '1 day'
  );
  raise exception 'scheduled a session in a squad the creator is not in';
exception
  when insufficient_privilege then
    null;
end $$;

-- The creator can't move the session to another squad or hand it to someone else.
do $$
begin
  begin
    update public.sq8_sessions
    set creator_id = 'dd000000-0000-4000-8000-000000000003'
    where id = 'dd200000-0000-4000-8000-000000000001';
    raise exception 'creator_id changed';
  exception
    when sqlstate 'P0001' then
      if sqlerrm is distinct from 'session_fixed_columns' then
        raise exception 'expected session_fixed_columns, got %', sqlerrm;
      end if;
    when insufficient_privilege then
      null;
  end;
  begin
    update public.sq8_sessions
    set created_at = now() - interval '1 day'
    where id = 'dd200000-0000-4000-8000-000000000001';
    raise exception 'created_at changed';
  exception
    when sqlstate 'P0001' then
      if sqlerrm is distinct from 'session_fixed_columns' then
        raise exception 'expected session_fixed_columns, got %', sqlerrm;
      end if;
  end;
end $$;

-- RSVPs: the creator says in, then out, then in again (the app's upsert).
insert into public.sq8_session_rsvps (session_id, user_id, response, updated_at)
values (
  'dd200000-0000-4000-8000-000000000001',
  'dd000000-0000-4000-8000-000000000002',
  'in',
  timestamptz '2000-01-01 00:00:00+00'
);

insert into public.sq8_session_rsvps (session_id, user_id, response)
values (
  'dd200000-0000-4000-8000-000000000001',
  'dd000000-0000-4000-8000-000000000002',
  'out'
)
on conflict (session_id, user_id) do update set response = excluded.response;

do $$
declare
  row record;
begin
  select response, updated_at into row
  from public.sq8_session_rsvps
  where session_id = 'dd200000-0000-4000-8000-000000000001'
    and user_id = 'dd000000-0000-4000-8000-000000000002';
  if row.response is distinct from 'out' then
    raise exception 'the upsert did not change the RSVP: %', row.response;
  end if;
  if row.updated_at < now() - interval '1 minute' then
    raise exception 'updated_at was taken from the client';
  end if;
end $$;

-- An RSVP can't be moved to another person.
do $$
begin
  update public.sq8_session_rsvps
  set user_id = 'dd000000-0000-4000-8000-000000000003'
  where session_id = 'dd200000-0000-4000-8000-000000000001'
    and user_id = 'dd000000-0000-4000-8000-000000000002';
  raise exception 'an RSVP moved to someone else';
exception
  when sqlstate 'P0001' then
    if sqlerrm is distinct from 'rsvp_fixed_columns' then
      raise exception 'expected rsvp_fixed_columns, got %', sqlerrm;
    end if;
  when insufficient_privilege then
    null;
end $$;

reset role;

-- Member 3 says in. Member 5 says in, then leaves the squad.
select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000003', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
values ('dd200000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000003', 'in');

-- Another member can't cancel: 0 rows.
do $$
declare
  changed integer;
begin
  update public.sq8_sessions
  set cancelled_at = now()
  where id = 'dd200000-0000-4000-8000-000000000001';
  get diagnostics changed = row_count;
  if changed is distinct from 0 then
    raise exception 'a member cancelled someone else''s session';
  end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000005', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
values ('dd200000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000005', 'in');
reset role;

delete from public.sq8_squad_members
where squad_id = 'dd100000-0000-4000-8000-000000000001'
  and user_id = 'dd000000-0000-4000-8000-000000000005';

-- Once they've left, 0016's select policy hides the row from them: 0 rows.
select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000005', false);
set role authenticated;
do $$
declare
  changed integer;
begin
  update public.sq8_session_rsvps
  set response = 'out'
  where session_id = 'dd200000-0000-4000-8000-000000000001'
    and user_id = 'dd000000-0000-4000-8000-000000000005';
  get diagnostics changed = row_count;
  if changed is distinct from 0 then
    raise exception 'someone who left changed an RSVP (% rows)', changed;
  end if;
end $$;
reset role;

-- And the guard refuses it even without RLS (the table owner here).
do $$
begin
  update public.sq8_session_rsvps
  set response = 'out'
  where session_id = 'dd200000-0000-4000-8000-000000000001'
    and user_id = 'dd000000-0000-4000-8000-000000000005';
  raise exception 'the guard let someone who left change an RSVP';
exception
  when sqlstate 'P0001' then
    if sqlerrm is distinct from 'not_in_squad' then
      raise exception 'expected not_in_squad, got %', sqlerrm;
    end if;
end $$;

-- The outsider (4) sees no sessions and no RSVPs, and can't RSVP.
select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000004', false);
set role authenticated;
do $$
begin
  if exists (select 1 from public.sq8_sessions where squad_id = 'dd100000-0000-4000-8000-000000000001') then
    raise exception 'an outsider read the squad''s sessions';
  end if;
  if exists (select 1 from public.sq8_session_rsvps where session_id = 'dd200000-0000-4000-8000-000000000001') then
    raise exception 'an outsider read the squad''s RSVPs';
  end if;
  begin
    insert into public.sq8_session_rsvps (session_id, user_id, response)
    values ('dd200000-0000-4000-8000-000000000001', 'dd000000-0000-4000-8000-000000000004', 'in');
    raise exception 'an outsider RSVPd';
  exception
    when insufficient_privilege then
      null;
    when sqlstate 'P0001' then
      null;
  end;
end $$;
reset role;

-- The creator cancels with a made-up time: the server's clock is stored.
select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000002', false);
set role authenticated;
update public.sq8_sessions
set cancelled_at = timestamptz '2000-01-01 00:00:00+00'
where id = 'dd200000-0000-4000-8000-000000000001';

do $$
begin
  if (select cancelled_at from public.sq8_sessions where id = 'dd200000-0000-4000-8000-000000000001')
    < now() - interval '1 minute' then
    raise exception 'cancelled_at was taken from the client';
  end if;
  -- Cancelling is final.
  begin
    update public.sq8_sessions
    set cancelled_at = null
    where id = 'dd200000-0000-4000-8000-000000000001';
    raise exception 'a cancelled session came back';
  exception
    when sqlstate 'P0001' then
      if sqlerrm is distinct from 'session_cancelled' then
        raise exception 'expected session_cancelled, got %', sqlerrm;
      end if;
  end;
  -- No RSVP changes on a cancelled session.
  begin
    update public.sq8_session_rsvps
    set response = 'in'
    where session_id = 'dd200000-0000-4000-8000-000000000001'
      and user_id = 'dd000000-0000-4000-8000-000000000002';
    raise exception 'an RSVP changed on a cancelled session';
  exception
    when sqlstate 'P0001' then
      if sqlerrm is distinct from 'session_cancelled' then
        raise exception 'expected session_cancelled, got %', sqlerrm;
      end if;
  end;
end $$;
reset role;

-- A session that's over (started 3 hours ago, no duration) takes no RSVPs.
-- Seeded with triggers off, as a row from before 0025 would be.
set session_replication_role = replica;
insert into public.sq8_sessions (id, squad_id, creator_id, game, starts_at)
values (
  'dd200000-0000-4000-8000-000000000002',
  'dd100000-0000-4000-8000-000000000001',
  'dd000000-0000-4000-8000-000000000002',
  'Apex',
  now() - interval '3 hours'
);
set session_replication_role = origin;

select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000003', false);
set role authenticated;
do $$
begin
  insert into public.sq8_session_rsvps (session_id, user_id, response)
  values ('dd200000-0000-4000-8000-000000000002', 'dd000000-0000-4000-8000-000000000003', 'in');
  raise exception 'an RSVP went in on a session that is over';
exception
  when sqlstate 'P0001' then
    if sqlerrm is distinct from 'session_over' then
      raise exception 'expected session_over, got %', sqlerrm;
    end if;
end $$;
reset role;

-- The same session with a 4 hour duration is still on: RSVPs work.
set session_replication_role = replica;
update public.sq8_sessions set duration_minutes = 240 where id = 'dd200000-0000-4000-8000-000000000002';
set session_replication_role = origin;

select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000003', false);
set role authenticated;
insert into public.sq8_session_rsvps (session_id, user_id, response)
values ('dd200000-0000-4000-8000-000000000002', 'dd000000-0000-4000-8000-000000000003', 'in');
reset role;

-- An embedded read like the app's: sessions with their RSVPs for a member.
select set_config('request.jwt.claim.sub', 'dd000000-0000-4000-8000-000000000003', false);
set role authenticated;
do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_sessions as s
  join public.sq8_session_rsvps as r on r.session_id = s.id
  where s.squad_id = 'dd100000-0000-4000-8000-000000000001';
  if n is distinct from 4 then
    raise exception 'member read % session RSVPs, expected 4', n;
  end if;
end $$;
reset role;
