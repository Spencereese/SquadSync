-- Proposed. Not applied. Spencer has to approve this before it runs.
-- Side groups and direct messages inside one sq8 squad.
-- Additive only. Does not alter sq8_messages, sq8_spot_calls, or the squad roster.
-- A person must already be a squad member. A DM is visible only to the
-- people who were added to that thread. A side group is visible only to
-- its thread members as well, so a guest is not in every side conversation.
-- anon and public get nothing.

create table if not exists public.sq8_threads (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  kind text not null,
  title text,
  created_by uuid not null references public.sq8_profiles (id),
  created_at timestamptz not null default now(),
  constraint sq8_threads_kind check (kind in ('side_group', 'dm')),
  constraint sq8_threads_title check (
    kind = 'dm' or (title is not null and char_length(btrim(title)) > 0)
  )
);

create table if not exists public.sq8_thread_members (
  thread_id uuid not null references public.sq8_threads (id) on delete cascade,
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  added_by uuid not null references public.sq8_profiles (id),
  added_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create table if not exists public.sq8_thread_messages (
  id uuid primary key,
  thread_id uuid not null references public.sq8_threads (id) on delete cascade,
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  sender_id uuid not null references public.sq8_profiles (id),
  body text not null,
  sent_at timestamptz not null,
  constraint sq8_thread_messages_body_not_blank check (char_length(btrim(body)) > 0)
);

create index if not exists sq8_thread_messages_paging
  on public.sq8_thread_messages (thread_id, sent_at desc, id desc);

alter table public.sq8_threads enable row level security;
alter table public.sq8_threads force row level security;
alter table public.sq8_thread_members enable row level security;
alter table public.sq8_thread_members force row level security;
alter table public.sq8_thread_messages enable row level security;
alter table public.sq8_thread_messages force row level security;

revoke all on public.sq8_threads from public, anon;
revoke all on public.sq8_thread_members from public, anon;
revoke all on public.sq8_thread_messages from public, anon;
grant select, insert on public.sq8_threads to authenticated;
grant select, insert on public.sq8_thread_members to authenticated;
grant select, insert on public.sq8_thread_messages to authenticated;

create or replace function sq8.is_thread_member(target_thread uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.sq8_thread_members
    where thread_id = target_thread
      and user_id = (select auth.uid())
  );
$$;

revoke all on function sq8.is_thread_member(uuid) from public, anon;
grant execute on function sq8.is_thread_member(uuid) to authenticated;

drop policy if exists sq8_threads_select on public.sq8_threads;
create policy sq8_threads_select
  on public.sq8_threads
  for select
  to authenticated
  using (
    sq8.is_member(squad_id)
    and sq8.is_thread_member(id)
  );

drop policy if exists sq8_threads_insert on public.sq8_threads;
create policy sq8_threads_insert
  on public.sq8_threads
  for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and sq8.is_member(squad_id)
  );

drop policy if exists sq8_thread_members_select on public.sq8_thread_members;
create policy sq8_thread_members_select
  on public.sq8_thread_members
  for select
  to authenticated
  using (sq8.is_thread_member(thread_id));

drop policy if exists sq8_thread_members_insert on public.sq8_thread_members;
create policy sq8_thread_members_insert
  on public.sq8_thread_members
  for insert
  to authenticated
  with check (
    added_by = (select auth.uid())
    and exists (
      select 1
      from public.sq8_threads as threads
      where threads.id = thread_id
        and sq8.is_member(threads.squad_id)
    )
    and exists (
      select 1
      from public.sq8_threads as threads
      join public.sq8_squad_members as members
        on members.squad_id = threads.squad_id
       and members.user_id = sq8_thread_members.user_id
      where threads.id = thread_id
    )
  );

drop policy if exists sq8_thread_messages_select on public.sq8_thread_messages;
create policy sq8_thread_messages_select
  on public.sq8_thread_messages
  for select
  to authenticated
  using (
    sq8.is_member(squad_id)
    and sq8.is_thread_member(thread_id)
  );

drop policy if exists sq8_thread_messages_insert on public.sq8_thread_messages;
create policy sq8_thread_messages_insert
  on public.sq8_thread_messages
  for insert
  to authenticated
  with check (
    sender_id = (select auth.uid())
    and sq8.is_member(squad_id)
    and sq8.is_thread_member(thread_id)
  );
