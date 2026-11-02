-- Slice 2. Not applied to the live project.
-- Tables are prefixed sq8_ because the old schema already has public.squads
-- and public.messages. profiles itself did not collide; the prefix keeps
-- this squad's tables in one namespace.

create schema if not exists sq8;

revoke all on schema sq8 from public;
grant usage on schema sq8 to authenticated;

create table public.sq8_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  default_game text not null default 'Call of Duty',
  constraint sq8_profiles_display_name_not_blank
    check (char_length(btrim(display_name)) > 0),
  constraint sq8_profiles_default_game_not_blank
    check (char_length(btrim(default_game)) > 0)
);

alter table public.sq8_profiles enable row level security;
alter table public.sq8_profiles force row level security;

revoke all on public.sq8_profiles from public, anon;
grant select, update on public.sq8_profiles to authenticated;

-- Signup creates the profile. Clients cannot insert a row for someone else.
create function sq8.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.sq8_profiles (id, display_name, default_game)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Player'
    ),
    'Call of Duty'
  );
  return new;
end;
$$;

revoke all on function sq8.handle_new_user() from public;

create trigger sq8_on_auth_user_created
  after insert on auth.users
  for each row
  execute function sq8.handle_new_user();

-- Own row only. Squad-mate reads are added once sq8_squad_members exists.
create policy sq8_profiles_select_own
  on public.sq8_profiles
  for select
  to authenticated
  using (id = (select auth.uid()));

create policy sq8_profiles_update
  on public.sq8_profiles
  for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
