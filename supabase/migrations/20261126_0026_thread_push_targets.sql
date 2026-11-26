-- Proposed. NOT applied. Needs Spencer's yes before it goes live.
-- Push for side-thread replies (sq8_thread_messages, from 0017 and 0024).
-- Additive only: two read-only functions and their public wrappers. No table,
-- policy, trigger, or Auth change. Idempotent: running it again is safe.
-- Apply after 0012 (device tokens) and 0017/0024 (side threads).
--
-- Who gets a reply's push: the people in that side thread (sq8_thread_members,
-- the same set row level security lets read it) who are still in the thread's
-- squad, and who have a device token. Never the sender, and never a device the
-- sender has registered too. The squad comes from the thread row, not from the
-- webhook body.
--
-- Executable by service_role only (when that role exists), like 0012's
-- sq8_message_push_targets. authenticated, anon, and public get nothing, so a
-- signed-in person cannot list other people's tokens.

create or replace function sq8.thread_push_targets(
  thread uuid,
  sender uuid
)
returns table (user_id uuid, token text, platform text)
language sql
stable
security definer
set search_path = ''
as $$
  select tokens.user_id, tokens.token, tokens.platform
  from public.sq8_threads as threads
  join public.sq8_thread_members as members
    on members.thread_id = threads.id
  join public.sq8_squad_members as squad_members
    on squad_members.squad_id = threads.squad_id
   and squad_members.user_id = members.user_id
  join public.sq8_device_tokens as tokens
    on tokens.user_id = members.user_id
  where threads.id = thread
    and members.user_id is distinct from sender
    and not exists (
      select 1
      from public.sq8_device_tokens as own
      where own.user_id = sender
        and own.token = tokens.token
    );
$$;

revoke all on function sq8.thread_push_targets(uuid, uuid) from public, anon, authenticated;

-- What the banner says: the sender's name and the thread's kind and title.
-- One row when the thread exists, none otherwise. No message text: the
-- function already has the reply body from the webhook record.
create or replace function sq8.thread_push_context(
  thread uuid,
  sender uuid
)
returns table (thread_kind text, thread_title text, sender_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select threads.kind, threads.title, profiles.display_name
  from public.sq8_threads as threads
  left join public.sq8_profiles as profiles
    on profiles.id = sender
  where threads.id = thread;
$$;

revoke all on function sq8.thread_push_context(uuid, uuid) from public, anon, authenticated;

-- PostgREST exposes public. The wrappers stay revoked from authenticated.
create or replace function public.sq8_thread_push_targets(
  thread uuid,
  sender uuid
)
returns table (user_id uuid, token text, platform text)
language sql
stable
security definer
set search_path = ''
as $$
  select targets.user_id, targets.token, targets.platform
  from sq8.thread_push_targets(thread, sender) as targets;
$$;

revoke all on function public.sq8_thread_push_targets(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.sq8_thread_push_context(
  thread uuid,
  sender uuid
)
returns table (thread_kind text, thread_title text, sender_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select context.thread_kind, context.thread_title, context.sender_name
  from sq8.thread_push_context(thread, sender) as context;
$$;

revoke all on function public.sq8_thread_push_context(uuid, uuid)
  from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function public.sq8_thread_push_targets(uuid, uuid) to service_role';
    execute 'grant execute on function public.sq8_thread_push_context(uuid, uuid) to service_role';
  end if;
end $$;

-- Down (commented out; run by hand only if this file must be undone):
-- drop function if exists public.sq8_thread_push_context(uuid, uuid);
-- drop function if exists public.sq8_thread_push_targets(uuid, uuid);
-- drop function if exists sq8.thread_push_context(uuid, uuid);
-- drop function if exists sq8.thread_push_targets(uuid, uuid);
