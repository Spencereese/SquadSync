-- Proposed. Not applied to the live project.
-- A person's own check-in for the one squad they belong to.
-- Does not read or write the old public.users, squads, or messages tables.
-- Does not depend on migration 0005. It does depend on sq8_profiles,
-- sq8_squads, sq8_squad_members, and sq8.is_member from files 1 and 2.
--
-- The phone does not get to decide that "available now" lasts longer than
-- 60 minutes. This trigger stamps checked_at and that window from the
-- database clock. "available later" stays that kind when its time arrives;
-- nothing here rewrites it to available now. Rows are not deleted on expiry.

create table public.sq8_check_ins (
  user_id uuid primary key references public.sq8_profiles (id) on delete cascade,
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  kind text not null,
  checked_at timestamptz not null,
  until_at timestamptz,
  constraint sq8_check_ins_kind
    check (kind in ('available_now', 'available_later', 'unavailable')),
  constraint sq8_check_ins_window check (
    (
      kind = 'unavailable'
      and until_at is null
    )
    or (
      kind = 'available_now'
      and until_at is not null
      and until_at > checked_at
      and until_at <= checked_at + interval '60 minutes'
    )
    or (
      kind = 'available_later'
      and until_at is not null
      and until_at > checked_at + interval '1 minute'
      and until_at <= checked_at + interval '7 days'
    )
  )
);

create index sq8_check_ins_squad on public.sq8_check_ins (squad_id);

alter table public.sq8_check_ins enable row level security;
alter table public.sq8_check_ins force row level security;

revoke all on public.sq8_check_ins from public, anon;
grant select, insert, update, delete on public.sq8_check_ins to authenticated;

create function sq8.stamp_check_in()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  stamped timestamptz := now();
begin
  if new.user_id is distinct from (select auth.uid()) then
    raise exception 'sq8_check_in_spoof' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.sq8_squad_members
    where squad_id = new.squad_id
      and user_id = (select auth.uid())
  ) then
    raise exception 'sq8_check_in_squad' using errcode = '42501';
  end if;

  new.checked_at := stamped;
  if new.kind = 'available_now' then
    new.until_at := stamped + interval '60 minutes';
  elsif new.kind = 'unavailable' then
    new.until_at := null;
  elsif new.kind = 'available_later' then
    if new.until_at is null
       or new.until_at <= stamped + interval '1 minute'
       or new.until_at > stamped + interval '7 days' then
      raise exception 'sq8_check_in_later_invalid' using errcode = '23514';
    end if;
  else
    raise exception 'sq8_check_in_kind' using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function sq8.stamp_check_in() from public;

create trigger sq8_check_ins_stamp
  before insert or update on public.sq8_check_ins
  for each row
  execute function sq8.stamp_check_in();

-- Leaving the squad removes that person's check-in. It does not remain visible.
create function sq8.clear_check_in_on_leave()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.sq8_check_ins
  where user_id = old.user_id
    and squad_id = old.squad_id;
  return old;
end;
$$;

revoke all on function sq8.clear_check_in_on_leave() from public;

create trigger sq8_squad_members_clear_check_in
  after delete on public.sq8_squad_members
  for each row
  execute function sq8.clear_check_in_on_leave();

create policy sq8_check_ins_select
  on public.sq8_check_ins
  for select
  to authenticated
  using (
    (select sq8.is_member(squad_id))
    and exists (
      select 1
      from public.sq8_squad_members as mate
      where mate.squad_id = sq8_check_ins.squad_id
        and mate.user_id = sq8_check_ins.user_id
    )
  );

create policy sq8_check_ins_insert
  on public.sq8_check_ins
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and (select sq8.is_member(squad_id))
  );

create policy sq8_check_ins_update
  on public.sq8_check_ins
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (select sq8.is_member(squad_id))
  );

create policy sq8_check_ins_delete
  on public.sq8_check_ins
  for delete
  to authenticated
  using (user_id = (select auth.uid()));
