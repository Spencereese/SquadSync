-- Ready to apply. Not applied. Not listed in supabase/tests/run.sh.
-- Spencer applies this file. The down section at the bottom is commented out.
-- A member can leave their squad. An owner who still has other members must
-- name one of them as the next owner, or the call returns owner_must_transfer.
-- A solo owner leaves by deleting that empty squad. The delete is allowed
-- through sq8.empty_squad_leave, which is the existing exception on the
-- owner-removal trigger. Check-ins clear through the member-delete trigger.
-- Apply after 0008. Does not grant anon or public.

create or replace function sq8.leave_squad(new_owner uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  mine_squad uuid;
  mine_owner uuid;
  member_count integer;
begin
  if me is null then
    return jsonb_build_object('ok', false, 'error', 'signed_out');
  end if;

  select members.squad_id
    into mine_squad
  from public.sq8_squad_members as members
  where members.user_id = me;

  if mine_squad is null then
    return jsonb_build_object('ok', false, 'error', 'already_left');
  end if;

  select squad.owner_id
    into mine_owner
  from public.sq8_squads as squad
  where squad.id = mine_squad
  for update;

  if mine_owner is null then
    return jsonb_build_object('ok', false, 'error', 'already_left');
  end if;

  select count(*)
    into member_count
  from public.sq8_squad_members
  where squad_id = mine_squad;

  if mine_owner = me and member_count > 1 then
    if new_owner is null
      or new_owner = me
      or not exists (
        select 1
        from public.sq8_squad_members
        where squad_id = mine_squad
          and user_id = new_owner
      )
    then
      return jsonb_build_object('ok', false, 'error', 'owner_must_transfer');
    end if;

    update public.sq8_squads
      set owner_id = new_owner
      where id = mine_squad;

    delete from public.sq8_squad_members
      where squad_id = mine_squad
        and user_id = me;

    return jsonb_build_object('ok', true, 'squad_id', mine_squad);
  end if;

  if mine_owner = me then
    insert into sq8.empty_squad_leave (user_id) values (me)
    on conflict (user_id) do nothing;
    begin
      delete from public.sq8_squads where id = mine_squad;
    exception
      when others then
        delete from sq8.empty_squad_leave where user_id = me;
        raise;
    end;
    delete from sq8.empty_squad_leave where user_id = me;
    return jsonb_build_object('ok', true, 'squad_id', null);
  end if;

  delete from public.sq8_squad_members
    where squad_id = mine_squad
      and user_id = me;

  return jsonb_build_object('ok', true, 'squad_id', mine_squad);
end;
$$;

revoke all on function sq8.leave_squad(uuid) from public, anon, authenticated;

create or replace function public.sq8_leave_squad(new_owner uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select sq8.leave_squad(new_owner);
$$;

revoke all on function public.sq8_leave_squad(uuid) from public, anon;
grant execute on function public.sq8_leave_squad(uuid) to authenticated;

-- Down. Do not run this with the up section. It only drops the two functions
-- this file creates. It does not touch tables, policies, or triggers.
--
-- revoke all on function public.sq8_leave_squad(uuid) from authenticated;
-- drop function if exists public.sq8_leave_squad(uuid);
-- drop function if exists sq8.leave_squad(uuid);
