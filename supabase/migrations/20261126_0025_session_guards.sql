-- NOT applied live. Needs Spencer's yes before anyone runs it on
-- sfckxrnoiwetmzdycqaa. Apply after 0016 (live since Nov 18, 2026).
--
-- Play sessions: server-side guards for the app's schedule and RSVP slice.
-- The app already works on 0016 alone; this file only tightens what 0016
-- lets a signed-in member do. It is additive and safe to run again.
--
--   1. Table privileges. Supabase's default privileges left `authenticated`
--      with DELETE, TRUNCATE, REFERENCES and TRIGGER on both tables, because
--      0016 revoked from public and anon only (checked read-only on Nov 26,
--      2026). TRUNCATE skips RLS. This puts back exactly what 0016 granted:
--      sessions select/insert/update, RSVPs select/insert/update/delete.
--   2. Session writes. id, squad, creator and created_at can't change. A time
--      that is set or moved has to be no more than 5 minutes ago and no more
--      than 60 days ahead. A game is at most 60 characters. Cancelling is final
--      and is stamped with the server's clock. created_at is the server's clock.
--   3. RSVP writes. Only for a session that isn't cancelled or over (start plus
--      duration, or plus 2 hours when there's no duration, the same window the
--      app uses), only while the person is still in that squad, and never
--      moved to another session or person. updated_at is the server's clock.
--
-- Doesn't touch non-sq8 tables. Doesn't grant anything to anon or public.
-- Existing rows aren't rewritten; the guards apply to new writes only.
-- Local check: supabase/tests/sq8_session_guards.sql (in tests/run.sh).

revoke delete, truncate, references, trigger on public.sq8_sessions from authenticated;
revoke truncate, references, trigger on public.sq8_session_rsvps from authenticated;
revoke all on public.sq8_sessions from public, anon;
revoke all on public.sq8_session_rsvps from public, anon;
grant select, insert, update on public.sq8_sessions to authenticated;
grant select, insert, update, delete on public.sq8_session_rsvps to authenticated;

create or replace function sq8.guard_session_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.cancelled_at is not null then
      raise exception 'session_cancelled' using errcode = 'P0001';
    end if;
    new.created_at := now();
  else
    if old.cancelled_at is not null then
      raise exception 'session_cancelled' using errcode = 'P0001';
    end if;
    if new.id is distinct from old.id
      or new.squad_id is distinct from old.squad_id
      or new.creator_id is distinct from old.creator_id
      or new.created_at is distinct from old.created_at then
      raise exception 'session_fixed_columns' using errcode = 'P0001';
    end if;
    if new.cancelled_at is not null then
      new.cancelled_at := now();
    end if;
  end if;

  if tg_op = 'INSERT' or new.starts_at is distinct from old.starts_at then
    if new.starts_at < now() - interval '5 minutes' then
      raise exception 'session_time_past' using errcode = 'P0001';
    end if;
    if new.starts_at > now() + interval '60 days' then
      raise exception 'session_time_far' using errcode = 'P0001';
    end if;
  end if;

  if (tg_op = 'INSERT' or new.game is distinct from old.game)
    and char_length(btrim(new.game)) > 60 then
    raise exception 'session_game_long' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

revoke all on function sq8.guard_session_write() from public, anon, authenticated;

drop trigger if exists sq8_sessions_guard on public.sq8_sessions;
create trigger sq8_sessions_guard
  before insert or update on public.sq8_sessions
  for each row
  execute function sq8.guard_session_write();

-- Security definer so the session and membership reads don't depend on what
-- the caller's own select policies return. It reads only; RLS still decides
-- whose row this is (0016: your own RSVP only).
create or replace function sq8.guard_session_rsvp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target record;
begin
  if tg_op = 'UPDATE'
    and (new.session_id is distinct from old.session_id
      or new.user_id is distinct from old.user_id) then
    raise exception 'rsvp_fixed_columns' using errcode = 'P0001';
  end if;

  select sessions.squad_id, sessions.starts_at, sessions.duration_minutes, sessions.cancelled_at
    into target
  from public.sq8_sessions as sessions
  where sessions.id = new.session_id;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0001';
  end if;
  if target.cancelled_at is not null then
    raise exception 'session_cancelled' using errcode = 'P0001';
  end if;
  if target.starts_at + make_interval(mins => coalesce(target.duration_minutes, 120)) <= now() then
    raise exception 'session_over' using errcode = 'P0001';
  end if;
  if not exists (
    select 1
    from public.sq8_squad_members as members
    where members.squad_id = target.squad_id
      and members.user_id = new.user_id
  ) then
    raise exception 'not_in_squad' using errcode = 'P0001';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

revoke all on function sq8.guard_session_rsvp() from public, anon, authenticated;

drop trigger if exists sq8_session_rsvps_guard on public.sq8_session_rsvps;
create trigger sq8_session_rsvps_guard
  before insert or update on public.sq8_session_rsvps
  for each row
  execute function sq8.guard_session_rsvp();
