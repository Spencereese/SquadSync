-- Slice 2. Not applied to the live project.
-- The old schema has public.chat_read_states (plural). This cursor is
-- sq8_chat_read_state. Opening one squad does not write another row.

create table public.sq8_chat_read_state (
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  last_read_at timestamptz not null,
  last_read_id uuid,
  primary key (user_id, squad_id)
);

alter table public.sq8_chat_read_state enable row level security;
alter table public.sq8_chat_read_state force row level security;

revoke all on public.sq8_chat_read_state from public, anon;
grant select, insert, update on public.sq8_chat_read_state to authenticated;

create policy sq8_read_state_select
  on public.sq8_chat_read_state
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    and sq8.is_member(squad_id)
  );

create policy sq8_read_state_insert
  on public.sq8_chat_read_state
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and sq8.is_member(squad_id)
  );

create policy sq8_read_state_update
  on public.sq8_chat_read_state
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
