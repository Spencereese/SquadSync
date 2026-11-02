-- Slice 2. Not applied to the live project.
-- public.messages and public.chat_messages already exist in the old schema.
-- This table is sq8_messages. The primary key is the client UUID.

create table public.sq8_messages (
  id uuid primary key,
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  sender_id uuid not null references public.sq8_profiles (id),
  body text not null,
  sent_at timestamptz not null,
  constraint sq8_messages_body_not_blank check (char_length(btrim(body)) > 0)
);

-- Newest-first paging. Equal timestamps break ties on id.
create index sq8_messages_paging
  on public.sq8_messages (squad_id, sent_at desc, id desc);

alter table public.sq8_messages enable row level security;
alter table public.sq8_messages force row level security;

revoke all on public.sq8_messages from public, anon;
grant select, insert on public.sq8_messages to authenticated;

create policy sq8_messages_select
  on public.sq8_messages
  for select
  to authenticated
  using (sq8.is_member(squad_id));

create policy sq8_messages_insert
  on public.sq8_messages
  for insert
  to authenticated
  with check (
    sender_id = (select auth.uid())
    and sq8.is_member(squad_id)
  );

-- Realtime echo. Create the publication only when this is not already a
-- Supabase database, then add the table once.
do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_messages'
  ) then
    alter publication supabase_realtime add table public.sq8_messages;
  end if;
end $$;
