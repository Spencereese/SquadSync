-- Applied live on Nov 18, 2026 (project sfckxrnoiwetmzdycqaa) with Spencer's yes.
-- Written for redesign S5 (onboarding). Nothing in the app needs it to work.
--
-- What it does: lets a profile keep the list of games someone plays, next to the
-- existing default_game. The app probes with a read-only
-- `select=games&id=eq.<me>`; until the column exists the list is saved on the
-- phone only and the profile step says so ("Your games list is saved on this
-- phone only. The server keeps your name and default game.").
--
-- Safety note:
--   - Additive only. One nullable column with no default, so Postgres adds it
--     without rewriting sq8_profiles and existing rows read as null.
--   - No backfill, no data change, no new grants. 0001 grants select/update on
--     the table to authenticated, and the existing policies already limit
--     writes to your own row and reads to you and your squad mates (0002), so
--     squad mates can see the list, which is the point. anon still gets nothing.
--   - The signup trigger (sq8.handle_new_user) is untouched; new profiles start
--     with games = null, which the app reads as an empty list.
--   - The check allows at most 12 games, each 1 to 40 characters after trimming,
--     the same limits the app enforces.
--   - Running it twice is safe (if not exists / or replace / guarded constraint).
--   - Rollback, if ever needed:
--       alter table public.sq8_profiles drop constraint if exists sq8_profiles_games_valid;
--       drop function if exists sq8.profile_games_valid(text[]);
--       alter table public.sq8_profiles drop column if exists games;

alter table public.sq8_profiles
  add column if not exists games text[];

create or replace function sq8.profile_games_valid(list text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select list is null or (
    cardinality(list) <= 12
    and coalesce((select bool_and(char_length(btrim(g)) between 1 and 40) from unnest(list) as g), true)
  );
$$;

revoke all on function sq8.profile_games_valid(text[]) from public;
grant execute on function sq8.profile_games_valid(text[]) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'sq8_profiles_games_valid'
  ) then
    alter table public.sq8_profiles
      add constraint sq8_profiles_games_valid
      check (sq8.profile_games_valid(games));
  end if;
end $$;
