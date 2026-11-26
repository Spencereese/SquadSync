-- NOT applied live. Written so that applying it live changes nothing.
-- Apply after 0013 and 0020. Safe to run again.
--
-- Reconciles the spot-call tables between this repo and project
-- sfckxrnoiwetmzdycqaa (read-only catalog check, Nov 26, 2026 about 3:40 AM CT).
--
-- What was compared, live against a database built from 0001-0026 in order:
--   columns, types, nullability and defaults of sq8_spot_calls and
--   sq8_spot_rsvps; their constraints, indexes, policies and triggers; the
--   realtime publication; and every sq8.* / public.sq8_* function whose name
--   has "spot" in it (md5 of pg_get_functiondef). All matched, including
--   seat_target integer not null default 8 with check 1..8, which file 0020
--   adds.
--
-- What actually differed:
--   1. supabase/tests/run.sh (the CI database) never applied 0018-0023, so the
--      fresh database CI tested had no seat_target, no ready, no 'expired'
--      status, no sq8_spot_rsvps_clear_ready trigger and none of 0020's
--      functions. run.sh now applies 0018-0023 after the 0013 spot test, the
--      way they landed on live data.
--   2. Table privileges. Live, authenticated holds every table privilege on
--      both tables (Supabase's default privileges); 0013 meant SELECT only.
--      Writes are still refused by forced RLS with select-only policies, but
--      TRUNCATE skips RLS. That is a security change, so it is NOT in this
--      file: it's 0030 (needs its own yes).
--
-- This file only states the 0020 shape again with existence checks, so a
-- database that somehow skipped 0020's DDL gets it, and live (which has it)
-- is untouched: no constraint is dropped or re-added, nothing is rewritten.
-- Functions are not redefined here (0020 owns them; their bodies match live).

alter table public.sq8_spot_calls
  add column if not exists seat_target integer not null default 8;

alter table public.sq8_spot_rsvps
  add column if not exists ready boolean not null default false;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'sq8_spot_calls_seat_target'
      and conrelid = 'public.sq8_spot_calls'::regclass
  ) then
    alter table public.sq8_spot_calls
      add constraint sq8_spot_calls_seat_target
      check (seat_target >= 1 and seat_target <= 8);
  end if;

  -- Only when the status check is missing 'expired' (a pre-0020 database).
  if not exists (
    select 1 from pg_constraint
    where conname = 'sq8_spot_calls_status'
      and conrelid = 'public.sq8_spot_calls'::regclass
      and pg_get_constraintdef(oid) like '%expired%'
  ) then
    alter table public.sq8_spot_calls
      drop constraint if exists sq8_spot_calls_status;
    alter table public.sq8_spot_calls
      add constraint sq8_spot_calls_status
      check (status in ('open', 'locked', 'ended', 'cancelled', 'expired'));
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname = 'sq8_spot_rsvps_clear_ready'
      and tgrelid = 'public.sq8_spot_rsvps'::regclass
  ) then
    if to_regprocedure('sq8.clear_spot_ready_on_response_change()') is null then
      raise exception 'apply 20261116_0020_ready_lock.sql before this file';
    end if;
    create trigger sq8_spot_rsvps_clear_ready
      before update of response on public.sq8_spot_rsvps
      for each row
      execute function sq8.clear_spot_ready_on_response_change();
  end if;
end $$;
