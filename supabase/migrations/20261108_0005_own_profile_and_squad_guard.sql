-- Proposed. Not applied to the live project.
-- Lets an existing auth user create only their own sq8_profiles row, and
-- stops two overlapping squad creates from seating the same owner twice
-- or pushing a squad past eight members.
-- Does not read or write the old public.users, squads, or messages tables.

grant insert on public.sq8_profiles to authenticated;

create policy sq8_profiles_insert_own
  on public.sq8_profiles
  for insert
  to authenticated
  with check (id = (select auth.uid()));

create unique index if not exists sq8_squads_one_owner
  on public.sq8_squads (owner_id);

-- Serialize the cap check on the squad row. A plain count can let two
-- inserts both observe seven members and both commit.
create or replace function sq8.reject_ninth_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  member_count integer;
begin
  perform 1
  from public.sq8_squads
  where id = new.squad_id
  for update;

  select count(*)
    into member_count
  from public.sq8_squad_members
  where squad_id = new.squad_id;

  if member_count >= 8 then
    raise exception 'sq8_squad_full' using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function sq8.reject_ninth_member() from public;
