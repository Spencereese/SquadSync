-- Proposed. Not applied. Spencer has to approve this before it runs.
-- Live sq8_squads is id, owner_id, created_at. The phone asks for a squad
-- name and shows "Your squad" until this column exists. The client does not
-- select or insert name while this file is unapplied.
-- Additive. Existing rows stay valid because name may be null.

alter table public.sq8_squads
  add column if not exists name text;

alter table public.sq8_squads
  drop constraint if exists sq8_squads_name_length;

alter table public.sq8_squads
  add constraint sq8_squads_name_length
  check (name is null or char_length(btrim(name)) between 1 and 40);
