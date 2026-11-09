-- Proposed. Not applied to the live project.
-- Invite codes for the one squad of eight. Does not read or write the old
-- public.users, squads, or messages tables.
-- Depends on files 1, 2, and 5 (the squad-row lock inside the member cap).
-- The code table is readable by the squad owner only. Joining goes through
-- sq8.join_with_code, which is not granted to API roles. authenticated may
-- call only the public wrappers.

create table public.sq8_invites (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid not null references public.sq8_squads (id) on delete cascade,
  code text not null unique,
  created_by uuid not null references public.sq8_profiles (id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  uses integer not null default 0,
  max_uses integer not null,
  revoked_at timestamptz,
  constraint sq8_invites_code_shape
    check (code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$'),
  constraint sq8_invites_uses_nonnegative
    check (uses >= 0 and max_uses >= 0 and uses <= max_uses)
);

create unique index sq8_invites_one_active
  on public.sq8_invites (squad_id)
  where revoked_at is null;

alter table public.sq8_invites enable row level security;
alter table public.sq8_invites force row level security;

revoke all on public.sq8_invites from public, anon;
grant select on public.sq8_invites to authenticated;

create policy sq8_invites_select_owner
  on public.sq8_invites
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.sq8_squads as squad
      where squad.id = squad_id
        and squad.owner_id = (select auth.uid())
    )
  );

-- Lets sq8.join_with_code delete an owned squad that has nobody else in it.
-- The owner-removal trigger otherwise blocks that delete. Callers cannot
-- write this table.
create table sq8.empty_squad_leave (
  user_id uuid primary key
);

revoke all on sq8.empty_squad_leave from public;

create or replace function sq8.reject_owner_removal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner uuid;
begin
  if exists (
    select 1
    from sq8.empty_squad_leave
    where user_id = old.user_id
  ) then
    return old;
  end if;

  select owner_id
    into owner
  from public.sq8_squads
  where id = old.squad_id;

  if old.user_id = owner then
    raise exception 'sq8_owner_protected' using errcode = '23514';
  end if;
  return old;
end;
$$;

revoke all on function sq8.reject_owner_removal() from public;

create function sq8.random_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  hex text;
  i integer;
  n integer;
  built text := '';
begin
  hex := replace(gen_random_uuid()::text, '-', '');
  for i in 0..7 loop
    n := ('x' || substr(hex, i * 2 + 1, 2))::bit(8)::integer % 32;
    built := built || substr(alphabet, n + 1, 1);
  end loop;
  return built;
end;
$$;

revoke all on function sq8.random_invite_code() from public;

create function sq8.normalize_invite_code(raw text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(
    regexp_replace(coalesce(raw, ''), '[^A-Za-z0-9]', '', 'g')
  );
$$;

revoke all on function sq8.normalize_invite_code(text) from public;

create function sq8.join_with_code(raw text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  normalized text;
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

  select *
    into inv
  from public.sq8_invites
  where code = normalized
  for update;

  if not found or inv.revoked_at is not null then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  if inv.expires_at <= now() then
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;

  perform 1
  from public.sq8_squads
  where id = inv.squad_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid');
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

  if member_count >= 8 or inv.uses >= inv.max_uses then
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

revoke all on function sq8.join_with_code(text) from public;

create function sq8.create_invite()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  squad uuid;
  seats integer;
  member_count integer;
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

  select count(*)
    into member_count
  from public.sq8_squad_members
  where squad_id = squad;

  seats := 8 - member_count;
  if seats < 1 then
    return jsonb_build_object('ok', false, 'error', 'full');
  end if;

  update public.sq8_invites
  set revoked_at = now()
  where squad_id = squad
    and revoked_at is null;

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
      values (squad, fresh, me, expires_at, seats);
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

revoke all on function sq8.create_invite() from public;

-- The only functions PostgREST should expose. Schema sq8 stays unexposed.
create function public.sq8_join_with_code(code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select sq8.join_with_code(code);
$$;

create function public.sq8_create_invite()
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select sq8.create_invite();
$$;

revoke all on function public.sq8_join_with_code(text) from public;
revoke all on function public.sq8_create_invite() from public;
grant execute on function public.sq8_join_with_code(text) to authenticated;
grant execute on function public.sq8_create_invite() to authenticated;
