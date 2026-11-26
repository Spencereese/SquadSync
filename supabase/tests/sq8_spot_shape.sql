-- 0027: after the whole chain, the spot tables have the shape live has
-- (read-only catalog check on sfckxrnoiwetmzdycqaa, Nov 26, 2026), and 0030
-- leaves authenticated with SELECT only. Not the live project.
\set ON_ERROR_STOP on

do $$
declare
  missing text[] := '{}';
begin
  if not exists (select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'sq8_spot_calls' and column_name = 'seat_target'
        and data_type = 'integer' and is_nullable = 'NO' and column_default = '8') then
    missing := missing || 'sq8_spot_calls.seat_target integer not null default 8';
  end if;
  if not exists (select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'sq8_spot_rsvps' and column_name = 'ready'
        and data_type = 'boolean' and is_nullable = 'NO' and column_default = 'false') then
    missing := missing || 'sq8_spot_rsvps.ready boolean not null default false';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sq8_spot_calls_seat_target'
      and pg_get_constraintdef(oid) = 'CHECK (((seat_target >= 1) AND (seat_target <= 8)))') then
    missing := missing || 'sq8_spot_calls_seat_target check';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sq8_spot_calls_status'
      and pg_get_constraintdef(oid) like '%expired%') then
    missing := missing || 'sq8_spot_calls_status with expired';
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'sq8_spot_rsvps_clear_ready') then
    missing := missing || 'sq8_spot_rsvps_clear_ready trigger';
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'sq8_squad_members_clear_spot_rsvps') then
    missing := missing || 'sq8_squad_members_clear_spot_rsvps trigger';
  end if;
  if to_regprocedure('public.sq8_read_open_spot(uuid)') is null
    or to_regprocedure('public.sq8_set_spot_ready(uuid, boolean)') is null
    or to_regprocedure('public.sq8_lock_spot_when_ready(uuid)') is null
    or to_regprocedure('sq8.expire_open_spot(uuid)') is null then
    missing := missing || '0020 spot functions';
  end if;
  if array_length(missing, 1) > 0 then
    raise exception 'spot tables differ from live: %', missing;
  end if;

  if has_table_privilege('authenticated', 'public.sq8_spot_calls', 'TRUNCATE')
    or has_table_privilege('authenticated', 'public.sq8_spot_calls', 'INSERT')
    or has_table_privilege('authenticated', 'public.sq8_spot_calls', 'DELETE')
    or has_table_privilege('authenticated', 'public.sq8_spot_rsvps', 'TRUNCATE')
    or has_table_privilege('authenticated', 'public.sq8_spot_rsvps', 'UPDATE') then
    raise exception 'authenticated has write privileges on the spot tables';
  end if;
  if not has_table_privilege('authenticated', 'public.sq8_spot_calls', 'SELECT')
    or not has_table_privilege('authenticated', 'public.sq8_spot_rsvps', 'SELECT') then
    raise exception 'authenticated lost SELECT on the spot tables';
  end if;
end $$;

select 'sq8 spot shape ok';
