-- Proposed. Not applied to the live project.
-- Safe after file 8. Files 9 and 10 may or may not be applied.
-- Idempotent. Does not grant execute to anon or public.
-- create or replace keeps the grants already on these functions, including
-- file 10's revokes when that file has been applied.
--
-- A removed member used to leave `uses` incremented. The next join was
-- refused once uses hit max_uses, even with an open seat. Capacity is the
-- live member count under the squad row lock. uses is only a counter.
--
-- Lock order matches create_invite: the squad row, then that squad's invite
-- rows. Join used to lock the invite first, so a concurrent rotate could
-- deadlock. The squad id is read without a row lock, the squad is locked,
-- and the invite is locked only after that.
--
-- Deleting the caller's empty squad happens after the target squad and its
-- invite are locked. That delete locks the empty squad row and then, through
-- the cascade, its invite rows. A join into that same empty squad takes the
-- squad row and then its invite, so those two sessions do not deadlock.
-- Two owners of empty squads who join each other's squads can: each holds
-- the other's squad and then waits to delete their own. That pair is outside
-- the rotate-versus-join order this function fixes.

alter table public.sq8_invites drop constraint if exists sq8_invites_uses_nonnegative;

alter table public.sq8_invites
  add constraint sq8_invites_uses_nonnegative
  check (uses >= 0 and max_uses >= 0);

create or replace function sq8.join_with_code(raw text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  normalized text;
  target_squad uuid;
  inv public.sq8_invites%rowtype;
  member_count integer;
  mine_squad uuid;
  mine_owner uuid;
  mine_count integer;
begin
  if me is null then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;

  normalized := sq8.normalize_invite_code(raw);
  if normalized !~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;

  select squad_id
    into target_squad
  from public.sq8_invites
  where code = normalized;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;

  perform 1
  from public.sq8_squads
  where id = target_squad
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;

  select *
    into inv
  from public.sq8_invites
  where code = normalized
    and squad_id = target_squad
  for update;

  if not found or inv.revoked_at is not null then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  if inv.expires_at <= now() then
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;

  if exists (
    select 1
    from public.sq8_squad_members
    where squad_id = inv.squad_id
      and user_id = me
  ) then
    return jsonb_build_object('ok', true, 'squad_id', inv.squad_id);
  end if;

  select count(*)
    into member_count
  from public.sq8_squad_members
  where squad_id = inv.squad_id;

  if member_count >= 8 then
    return jsonb_build_object('ok', false, 'error', 'full');
  end if;

  select members.squad_id, squad.owner_id
    into mine_squad, mine_owner
  from public.sq8_squad_members as members
  join public.sq8_squads as squad on squad.id = members.squad_id
  where members.user_id = me;

  if mine_squad is not null then
    select count(*)
      into mine_count
    from public.sq8_squad_members
    where squad_id = mine_squad;

    if mine_owner = me and mine_count = 1 then
      insert into sq8.empty_squad_leave (user_id) values (me);
      -- Squad row first, then cascaded invite rows. Same order as a join
      -- into this empty squad, so that join does not deadlock with this delete.
      delete from public.sq8_squads where id = mine_squad;
      delete from sq8.empty_squad_leave where user_id = me;
    elsif mine_owner = me then
      return jsonb_build_object('ok', false, 'error', 'owns_squad_with_members');
    else
      return jsonb_build_object('ok', false, 'error', 'already_in_squad');
    end if;
  end if;

  insert into public.sq8_squad_members (squad_id, user_id)
  values (inv.squad_id, me);

  update public.sq8_invites
  set uses = uses + 1
  where id = inv.id;

  return jsonb_build_object('ok', true, 'squad_id', inv.squad_id);
end;
$$;

create or replace function sq8.create_invite()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  fresh text;
  attempt integer := 0;
  expires_at timestamptz;
begin
  if me is null then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;

  select id
    into squad
  from public.sq8_squads
  where owner_id = me
  for update;

  if squad is null then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;

  update public.sq8_invites
  set revoked_at = now()
  where squad_id = squad
    and revoked_at is null;

  -- max_uses is not a remaining-seat budget. Joins ignore it.
  expires_at := now() + interval '7 days';
  loop
    attempt := attempt + 1;
    fresh := sq8.random_invite_code();
    begin
      insert into public.sq8_invites (
        squad_id,
        code,
        created_by,
        expires_at,
        max_uses
      )
      values (squad, fresh, me, expires_at, 8);
      exit;
    exception
      when unique_violation then
        if attempt >= 5 then
          raise;
        end if;
    end;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'code', fresh,
    'expires_at', expires_at,
    'squad_id', squad
  );
end;
$$;

revoke all on function sq8.join_with_code(text) from public, anon;
revoke all on function sq8.create_invite() from public, anon;
