-- Proposed. Not applied to the live project.
-- Reactions, a shared per-member read cursor, and an optional reply on a
-- message. Typing is not stored: the phone uses a realtime broadcast.
-- Members of the squad can read. A person writes only their own reaction
-- and their own cursor. anon and public get nothing.
-- Running this file again is safe.

alter table public.sq8_messages
  add column if not exists reply_to_id uuid references public.sq8_messages (id)
    on delete set null;

create table if not exists public.sq8_message_reactions (
  message_id uuid not null references public.sq8_messages (id) on delete cascade,
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji),
  constraint sq8_message_reactions_emoji
    check (emoji in ('👍', '😂', '🔥', '❤️', '😮', '🎮'))
);

create index if not exists sq8_message_reactions_squad
  on public.sq8_message_reactions (squad_id);

create table if not exists public.sq8_message_reads (
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  last_read_at timestamptz not null,
  last_read_id uuid references public.sq8_messages (id) on delete set null,
  primary key (user_id, squad_id)
);

create index if not exists sq8_message_reads_squad
  on public.sq8_message_reads (squad_id);

alter table public.sq8_message_reactions enable row level security;
alter table public.sq8_message_reactions force row level security;
alter table public.sq8_message_reads enable row level security;
alter table public.sq8_message_reads force row level security;

revoke all on public.sq8_message_reactions from public, anon;
revoke all on public.sq8_message_reads from public, anon;
grant select, insert, delete on public.sq8_message_reactions to authenticated;
grant select, insert, update on public.sq8_message_reads to authenticated;

drop policy if exists sq8_message_reactions_select on public.sq8_message_reactions;
create policy sq8_message_reactions_select
  on public.sq8_message_reactions
  for select
  to authenticated
  using (sq8.is_member(squad_id));

drop policy if exists sq8_message_reactions_insert on public.sq8_message_reactions;
create policy sq8_message_reactions_insert
  on public.sq8_message_reactions
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and sq8.is_member(squad_id)
    and exists (
      select 1
      from public.sq8_messages as messages
      where messages.id = message_id
        and messages.squad_id = sq8_message_reactions.squad_id
    )
  );

drop policy if exists sq8_message_reactions_delete on public.sq8_message_reactions;
create policy sq8_message_reactions_delete
  on public.sq8_message_reactions
  for delete
  to authenticated
  using (
    user_id = (select auth.uid())
    and sq8.is_member(squad_id)
  );

drop policy if exists sq8_message_reads_select on public.sq8_message_reads;
create policy sq8_message_reads_select
  on public.sq8_message_reads
  for select
  to authenticated
  using (sq8.is_member(squad_id));

drop policy if exists sq8_message_reads_insert on public.sq8_message_reads;
create policy sq8_message_reads_insert
  on public.sq8_message_reads
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and sq8.is_member(squad_id)
  );

drop policy if exists sq8_message_reads_update on public.sq8_message_reads;
create policy sq8_message_reads_update
  on public.sq8_message_reads
  for update
  to authenticated
  using (
    user_id = (select auth.uid())
    and sq8.is_member(squad_id)
  )
  with check (
    user_id = (select auth.uid())
    and sq8.is_member(squad_id)
  );

-- Realtime DELETE payloads for a reaction carry the primary key only
-- (message_id, user_id, emoji), not squad_id. The phone does not filter
-- those deletes.
do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['sq8_message_reactions', 'sq8_message_reads']
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end $$;
