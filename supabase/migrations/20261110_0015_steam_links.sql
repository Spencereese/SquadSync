-- Proposed. Not applied to the live project.
-- One SteamID64 per person. The person writes only their own row and can
-- read only their own row. Other members do not receive the id. The presence
-- function reads it with the service role after it has checked the caller's
-- squad. anon and public get nothing.
-- Running this file again is safe.

create table if not exists public.sq8_steam_links (
  user_id uuid primary key references public.sq8_profiles (id) on delete cascade,
  steam_id text not null,
  updated_at timestamptz not null default now(),
  constraint sq8_steam_links_id64 check (steam_id ~ '^[0-9]{17}$')
);

alter table public.sq8_steam_links enable row level security;
alter table public.sq8_steam_links force row level security;

revoke all on public.sq8_steam_links from public, anon;
grant select, insert, update, delete on public.sq8_steam_links to authenticated;

drop policy if exists sq8_steam_links_select_own on public.sq8_steam_links;
create policy sq8_steam_links_select_own
  on public.sq8_steam_links
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists sq8_steam_links_insert_own on public.sq8_steam_links;
create policy sq8_steam_links_insert_own
  on public.sq8_steam_links
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists sq8_steam_links_update_own on public.sq8_steam_links;
create policy sq8_steam_links_update_own
  on public.sq8_steam_links
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists sq8_steam_links_delete_own on public.sq8_steam_links;
create policy sq8_steam_links_delete_own
  on public.sq8_steam_links
  for delete
  to authenticated
  using (user_id = (select auth.uid()));
