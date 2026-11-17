-- UNAPPLIED. Proposed for redesign S4 (who's in). Do not apply without Spencer's yes.
-- Not applied to the live project. Nothing in the app needs it to work.
--
-- What it does: lets a check-in carry what the person says they're playing and
-- on which console. Both are optional, typed by the person, and never verified
-- (honor system). The app probes for these columns with a read-only
-- `select=game,platform&limit=1`; until they exist it saves check-ins without
-- them and the sheet says "This server saves when you're on, not the game or
-- console yet."
--
-- Safety note:
--   - Additive only. Two nullable columns with no default, so Postgres adds them
--     without rewriting sq8_check_ins and existing rows read as null.
--   - No backfill, no data change, no new grants. The existing sq8_check_ins row
--     level security (members read their squad, each person writes only their
--     own row) already covers new columns. anon and public still get nothing.
--   - The 0006 stamp trigger is not replaced. A second BEFORE trigger only trims
--     the game and clears both fields on "unavailable".
--   - 0009 already publishes sq8_check_ins to realtime; nothing changes there.
--   - Running it twice is safe (if not exists / or replace / drop if exists).
--   - Rollback, if ever needed:
--       drop trigger if exists sq8_check_ins_details on public.sq8_check_ins;
--       drop function if exists sq8.tidy_check_in_details();
--       alter table public.sq8_check_ins drop column if exists platform, drop column if exists game;

alter table public.sq8_check_ins
  add column if not exists game text,
  add column if not exists platform text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'sq8_check_ins_game_length'
  ) then
    alter table public.sq8_check_ins
      add constraint sq8_check_ins_game_length
      check (game is null or char_length(game) between 1 and 40);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'sq8_check_ins_platform'
  ) then
    alter table public.sq8_check_ins
      add constraint sq8_check_ins_platform
      check (platform is null or platform in ('playstation', 'xbox', 'switch', 'pc', 'mobile'));
  end if;
end $$;

create or replace function sq8.tidy_check_in_details()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind = 'unavailable' then
    new.game := null;
    new.platform := null;
  else
    new.game := nullif(btrim(new.game), '');
  end if;
  return new;
end;
$$;

revoke all on function sq8.tidy_check_in_details() from public;

drop trigger if exists sq8_check_ins_details on public.sq8_check_ins;
create trigger sq8_check_ins_details
  before insert or update on public.sq8_check_ins
  for each row
  execute function sq8.tidy_check_in_details();
