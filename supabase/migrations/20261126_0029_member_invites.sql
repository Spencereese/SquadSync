-- NOT applied live. Needs Spencer's yes before it runs on sfckxrnoiwetmzdycqaa.
-- Apply after 0008, 0010 and 0011. Additive and safe to run again.
--
-- Any member can get the group's invite link. Today (live 0008/0010/0011)
-- sq8_create_invite is owner-only and every call revokes the previous code.
-- This adds public.sq8_member_invite(), which:
--   * needs the caller to be a member of a group (the owner is a member too);
--   * hands back the group's current invite when it has more than a day left,
--     so two people sharing a link never cancel each other's;
--   * otherwise revokes the old one and makes a fresh 7-day code, exactly the
--     way 0011 does (same code shape, same max_uses value, same retry).
-- The 8-person cap is unchanged: sq8.join_with_code (0011) still counts
-- members under the squad lock. Removing people stays owner-only.
-- sq8_create_invite and sq8_join_with_code are not replaced, so old builds
-- keep working. Nothing is granted to anon or public.
-- Lock order matches 0011: the squad row, then its invites.
-- Local check: supabase/tests/sq8_member_invites.sql.

create or replace function sq8.member_invite()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  current public.sq8_invites%rowtype;
  fresh text;
  attempt integer := 0;
  expires timestamptz;
begin
  if me is null then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;

  select members.squad_id into squad
  from public.sq8_squad_members as members
  where members.user_id = me
  limit 1;
  if squad is null then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;

  perform 1 from public.sq8_squads where id = squad for update;

  -- Still a member once the lock is held.
  if not exists (
    select 1 from public.sq8_squad_members
    where squad_id = squad and user_id = me
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;

  select * into current
  from public.sq8_invites
  where squad_id = squad and revoked_at is null
  for update;

  if found and current.expires_at > now() + interval '1 day' then
    return jsonb_build_object(
      'ok', true,
      'code', current.code,
      'expires_at', current.expires_at,
      'squad_id', squad
    );
  end if;

  update public.sq8_invites
  set revoked_at = now()
  where squad_id = squad and revoked_at is null;

  expires := now() + interval '7 days';
  loop
    attempt := attempt + 1;
    fresh := sq8.random_invite_code();
    begin
      insert into public.sq8_invites (squad_id, code, created_by, expires_at, max_uses)
      values (squad, fresh, me, expires, 8);
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
    'expires_at', expires,
    'squad_id', squad
  );
end;
$$;

revoke all on function sq8.member_invite() from public, anon, authenticated;

create or replace function public.sq8_member_invite()
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.member_invite();
$$;

revoke all on function public.sq8_member_invite() from public, anon;
grant execute on function public.sq8_member_invite() to authenticated;

-- down
-- drop function if exists public.sq8_member_invite();
-- drop function if exists sq8.member_invite();
