-- UNAPPLIED. Proposed security fix for 0017 (side threads). Do not apply without Spencer's yes.
-- Not applied to the live project. Idempotent: running it again is safe.
--
-- Written against the live 0017 objects as read (read-only) on Nov 18, 2026:
-- tables public.sq8_threads / sq8_thread_members / sq8_thread_messages,
-- policies sq8_thread_members_insert and sq8_thread_messages_insert, helpers
-- sq8.is_member(uuid) and sq8.is_thread_member(uuid). No triggers existed.
--
-- What it fixes:
-- (a) Today any squad member can add anyone in the squad to any thread of that
--     squad, including a DM or side group they aren't in. Now the adder must be
--     the thread's creator or already a member of that thread (and still in the
--     squad), and the added person must be in the thread's squad.
-- (b) A DM has no member limit. Now a DM holds at most 2 people. A trigger locks
--     the thread row before counting, so two overlapping adds can't both pass.
-- (c) A thread message's squad_id was checked only against the sender's squads,
--     not the thread's. Now squad_id must be the thread's squad (policy plus a
--     trigger, so no writer can file a message under another squad), and the
--     sender must be a member of the thread.
--
-- Before applying, this should return no rows (a DM already over 2 would make
-- later adds fail, but this file does not delete anything):
--   select thread_id, count(*) from public.sq8_thread_members tm
--   join public.sq8_threads t on t.id = tm.thread_id
--   where t.kind = 'dm' group by thread_id having count(*) > 2;
-- and this should return no rows (messages filed under the wrong squad):
--   select m.id from public.sq8_thread_messages m
--   join public.sq8_threads t on t.id = m.thread_id
--   where m.squad_id is distinct from t.squad_id;
--
-- anon and public get nothing. Nothing here changes Auth.

-- (a) Who may add whom to a thread.
create or replace function sq8.can_add_thread_member(target_thread uuid, target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.sq8_threads as threads
    where threads.id = target_thread
      and sq8.is_member(threads.squad_id)
      and (
        threads.created_by = (select auth.uid())
        or exists (
          select 1
          from public.sq8_thread_members as current_members
          where current_members.thread_id = threads.id
            and current_members.user_id = (select auth.uid())
        )
      )
      and exists (
        select 1
        from public.sq8_squad_members as squad_members
        where squad_members.squad_id = threads.squad_id
          and squad_members.user_id = target_user
      )
  );
$$;

revoke all on function sq8.can_add_thread_member(uuid, uuid) from public, anon;
grant execute on function sq8.can_add_thread_member(uuid, uuid) to authenticated;

drop policy if exists sq8_thread_members_insert on public.sq8_thread_members;
create policy sq8_thread_members_insert
  on public.sq8_thread_members
  for insert
  to authenticated
  with check (
    added_by = (select auth.uid())
    and sq8.can_add_thread_member(thread_id, user_id)
  );

-- (b) A DM holds at most two people.
create or replace function sq8.thread_members_dm_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  thread_kind text;
  others integer;
begin
  select kind into thread_kind
  from public.sq8_threads
  where id = new.thread_id
  for update;

  if thread_kind = 'dm' then
    select count(*) into others
    from public.sq8_thread_members
    where thread_id = new.thread_id
      and user_id <> new.user_id;
    if others >= 2 then
      raise exception 'sq8_dm_full' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function sq8.thread_members_dm_cap() from public, anon, authenticated;

drop trigger if exists sq8_thread_members_dm_cap on public.sq8_thread_members;
create trigger sq8_thread_members_dm_cap
  before insert or update of thread_id, user_id on public.sq8_thread_members
  for each row
  execute function sq8.thread_members_dm_cap();

-- (c) A thread message belongs to its thread's squad, from a thread member.
create or replace function sq8.thread_in_squad(target_thread uuid, target_squad uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.sq8_threads
    where id = target_thread
      and squad_id = target_squad
  );
$$;

revoke all on function sq8.thread_in_squad(uuid, uuid) from public, anon;
grant execute on function sq8.thread_in_squad(uuid, uuid) to authenticated;

create or replace function sq8.thread_messages_squad_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.sq8_threads
    where id = new.thread_id
      and squad_id = new.squad_id
  ) then
    raise exception 'sq8_thread_squad_mismatch' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

revoke all on function sq8.thread_messages_squad_match() from public, anon, authenticated;

do $$
declare
  has_squad boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'sq8_thread_messages'
      and column_name = 'squad_id'
  ) into has_squad;

  execute 'drop policy if exists sq8_thread_messages_insert on public.sq8_thread_messages';
  execute 'drop trigger if exists sq8_thread_messages_squad_match on public.sq8_thread_messages';

  if has_squad then
    execute $policy$
      create policy sq8_thread_messages_insert
        on public.sq8_thread_messages
        for insert
        to authenticated
        with check (
          sender_id = (select auth.uid())
          and sq8.is_member(squad_id)
          and sq8.thread_in_squad(thread_id, squad_id)
          and sq8.is_thread_member(thread_id)
        )
    $policy$;
    execute $trigger$
      create trigger sq8_thread_messages_squad_match
        before insert or update of thread_id, squad_id on public.sq8_thread_messages
        for each row
        execute function sq8.thread_messages_squad_match()
    $trigger$;
  else
    execute $policy$
      create policy sq8_thread_messages_insert
        on public.sq8_thread_messages
        for insert
        to authenticated
        with check (
          sender_id = (select auth.uid())
          and sq8.is_thread_member(thread_id)
        )
    $policy$;
  end if;
end $$;
