-- Slice 2. Not applied to the live project.
-- public.squads already exists in the old schema, so this squad is sq8_squads.

create table public.sq8_squads (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.sq8_profiles (id),
  created_at timestamptz not null default now()
);

create table public.sq8_squad_members (
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  primary key (squad_id, user_id)
);

-- One private squad: a person is a member of at most one.
create unique index sq8_squad_members_one_squad
  on public.sq8_squad_members (user_id);

alter table public.sq8_squads enable row level security;
alter table public.sq8_squads force row level security;
alter table public.sq8_squad_members enable row level security;
alter table public.sq8_squad_members force row level security;

revoke all on public.sq8_squads from public, anon;
revoke all on public.sq8_squad_members from public, anon;
grant select, insert on public.sq8_squads to authenticated;
grant select, insert, delete on public.sq8_squad_members to authenticated;

-- Reads membership without going through RLS, so policies can call it
-- without recursing. Lives in schema sq8, which is not exposed to the API.
create function sq8.is_member(target_squad uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.sq8_squad_members
    where squad_id = target_squad
      and user_id = (select auth.uid())
  );
$$;

revoke all on function sq8.is_member(uuid) from public;
grant execute on function sq8.is_member(uuid) to authenticated;

create function sq8.reject_ninth_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  member_count integer;
begin
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

create trigger sq8_squad_members_cap
  before insert on public.sq8_squad_members
  for each row
  execute function sq8.reject_ninth_member();

create function sq8.reject_owner_removal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner uuid;
begin
  select owner_id
    into owner
  from public.sq8_squads
  where id = old.squad_id;

  if old.user_id = owner then
    raise exception 'sq8_owner_protected' using errcode = '23514';
  end if;
  return old;
end;
$$;

revoke all on function sq8.reject_owner_removal() from public;

create trigger sq8_squad_members_owner
  before delete on public.sq8_squad_members
  for each row
  execute function sq8.reject_owner_removal();

-- Creating a squad also seats the owner. The cap trigger still applies.
create function sq8.add_owner_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.sq8_squad_members (squad_id, user_id)
  values (new.id, new.owner_id);
  return new;
end;
$$;

revoke all on function sq8.add_owner_member() from public;

create trigger sq8_squads_seat_owner
  after insert on public.sq8_squads
  for each row
  execute function sq8.add_owner_member();

-- Members can read the profiles of the other people in their squad.
create policy sq8_profiles_select_squad
  on public.sq8_profiles
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.sq8_squad_members mine
      join public.sq8_squad_members theirs
        on theirs.squad_id = mine.squad_id
      where mine.user_id = (select auth.uid())
        and theirs.user_id = sq8_profiles.id
    )
  );

create policy sq8_squads_select
  on public.sq8_squads
  for select
  to authenticated
  using (sq8.is_member(id));

create policy sq8_squads_insert
  on public.sq8_squads
  for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

create policy sq8_members_select
  on public.sq8_squad_members
  for select
  to authenticated
  using (sq8.is_member(squad_id));

create policy sq8_members_insert
  on public.sq8_squad_members
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.sq8_squads
      where id = squad_id
        and owner_id = (select auth.uid())
    )
  );

create policy sq8_members_delete
  on public.sq8_squad_members
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.sq8_squads
      where id = squad_id
        and owner_id = (select auth.uid())
    )
  );
