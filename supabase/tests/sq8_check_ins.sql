-- Check-in visibility. Not for the live project.
\set ON_ERROR_STOP on

-- Member checks in as available now. The trigger owns the 60 minute window.
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', false);
set role authenticated;

insert into public.sq8_check_ins (user_id, squad_id, kind, checked_at, until_at)
values (
  'a0000000-0000-4000-8000-000000000002',
  'b0000000-0000-4000-8000-000000000001',
  'available_now',
  timestamptz '2000-01-01 00:00:00+00',
  timestamptz '2000-01-02 00:00:00+00'
);

do $$
declare
  span interval;
  kind text;
begin
  select until_at - checked_at, sq8_check_ins.kind
    into span, kind
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if kind is distinct from 'available_now' or span is distinct from interval '60 minutes' then
    raise exception 'available now was stored as % spanning %', kind, span;
  end if;
end $$;

-- A squad mate can read it. A non-member cannot.
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000003', false);

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if n <> 1 then
    raise exception 'squad mate saw % check-ins, expected 1', n;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-00000000000a', false);

do $$
declare
  n integer;
begin
  select count(*) into n from public.sq8_check_ins;
  if n <> 0 then
    raise exception 'non-member saw % check-ins', n;
  end if;
end $$;

do $$
begin
  insert into public.sq8_check_ins (user_id, squad_id, kind, checked_at)
  values (
    'a0000000-0000-4000-8000-00000000000a',
    'b0000000-0000-4000-8000-000000000001',
    'available_now',
    now()
  );
  raise exception 'non-member check-in was accepted';
exception
  when insufficient_privilege then
    null;
end $$;

-- A mate cannot write someone else's row.
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000003', false);

do $$
begin
  insert into public.sq8_check_ins (user_id, squad_id, kind, checked_at)
  values (
    'a0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000001',
    'unavailable',
    now()
  );
  raise exception 'spoofed check-in insert was accepted';
exception
  when insufficient_privilege then
    null;
end $$;

update public.sq8_check_ins
set kind = 'unavailable'
where user_id = 'a0000000-0000-4000-8000-000000000002';

delete from public.sq8_check_ins
where user_id = 'a0000000-0000-4000-8000-000000000002';

do $$
declare
  kind text;
  n integer;
begin
  select count(*), max(sq8_check_ins.kind)
    into n, kind
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if n <> 1 or kind is distinct from 'available_now' then
    raise exception 'spoofed write changed the row to % (% rows)', kind, n;
  end if;
end $$;

-- Later stays later, including after the chosen time. It is not rewritten to now.
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', false);

update public.sq8_check_ins
set kind = 'available_later',
    until_at = now() + interval '2 hours'
where user_id = 'a0000000-0000-4000-8000-000000000002';

do $$
declare
  kind text;
begin
  select sq8_check_ins.kind into kind
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if kind is distinct from 'available_later' then
    raise exception 'later check-in stored as %', kind;
  end if;
end $$;

do $$
begin
  update public.sq8_check_ins
  set kind = 'available_later',
      until_at = now() + interval '30 seconds'
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  raise exception 'later inside one minute was accepted';
exception
  when check_violation then
    if sqlerrm not like '%sq8_check_in_later_invalid%' then
      raise;
    end if;
end $$;

do $$
begin
  update public.sq8_check_ins
  set kind = 'available_later',
      until_at = now() + interval '8 days'
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  raise exception 'later beyond 7 days was accepted';
exception
  when check_violation then
    if sqlerrm not like '%sq8_check_in_later_invalid%' then
      raise;
    end if;
end $$;

reset role;
alter table public.sq8_check_ins disable trigger sq8_check_ins_stamp;
update public.sq8_check_ins
set checked_at = now() - interval '2 hours',
    until_at = now() - interval '1 minute'
where user_id = 'a0000000-0000-4000-8000-000000000002';
alter table public.sq8_check_ins enable trigger sq8_check_ins_stamp;

do $$
declare
  kind text;
begin
  select sq8_check_ins.kind into kind
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if kind is distinct from 'available_later' then
    raise exception 'a due later row was rewritten to %', kind;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', false);
set role authenticated;

update public.sq8_check_ins
set kind = 'unavailable',
    until_at = now() + interval '1 day'
where user_id = 'a0000000-0000-4000-8000-000000000002';

do $$
declare
  kind text;
  until_at timestamptz;
begin
  select sq8_check_ins.kind, sq8_check_ins.until_at
    into kind, until_at
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if kind is distinct from 'unavailable' or until_at is not null then
    raise exception 'unavailable stored as % until %', kind, until_at;
  end if;
end $$;

-- Another squad cannot see this row, and this squad cannot see theirs.
reset role;

insert into auth.users (id, email)
values ('a0000000-0000-4000-8000-00000000000c', 'other-squad@example.com');

insert into public.sq8_squads (id, owner_id)
values (
  'b0000000-0000-4000-8000-000000000002',
  'a0000000-0000-4000-8000-00000000000c'
);

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-00000000000c', false);
set role authenticated;

insert into public.sq8_check_ins (user_id, squad_id, kind, checked_at)
values (
  'a0000000-0000-4000-8000-00000000000c',
  'b0000000-0000-4000-8000-000000000002',
  'available_now',
  now()
);

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if n <> 0 then
    raise exception 'other squad read a check-in';
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', false);

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-00000000000c';
  if n <> 0 then
    raise exception 'this squad read the other squad check-in';
  end if;
end $$;

delete from public.sq8_check_ins
where user_id = 'a0000000-0000-4000-8000-000000000002';

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.sq8_check_ins
  where user_id = 'a0000000-0000-4000-8000-000000000002';
  if n <> 0 then
    raise exception 'clear left % rows', n;
  end if;
end $$;

reset role;
set role anon;

do $$
begin
  perform 1 from public.sq8_check_ins;
  raise exception 'anon read check-ins';
exception
  when insufficient_privilege then
    null;
end $$;

reset role;
