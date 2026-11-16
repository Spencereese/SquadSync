-- Proposed. Not applied. Needs Spencer's yes before it runs anywhere.
-- Does not grant anon or public. authenticated gets the public wrapper only.
-- Does not add an UPDATE policy. Live sq8_squads allows select and insert only.
-- Null clears the name. Any other value must be 1 to 40 characters after trim.
--
-- Realtime: 0009 publishes sq8_squad_members and sq8_check_ins, not sq8_squads.
-- This file adds sq8_squads to supabase_realtime. Members can already select
-- that row, so the UPDATE is delivered to them. The client subscribes with
-- id=eq.<squad> and reloads the squad on that event, the same path as a
-- roster change. A later currentSquad load also reads name if the socket
-- missed it. Down drops the table from the publication. It does not drop
-- the name column from 0018, and it does not restore a renamed value.

create or replace function sq8.rename_squad(squad uuid, new_name text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  owner uuid;
  trimmed text := nullif(btrim(new_name), '');
begin
  if me is null then
    return jsonb_build_object('ok', false, 'error', 'signed_out');
  end if;
  if trimmed is not null and char_length(trimmed) > 40 then
    return jsonb_build_object('ok', false, 'error', 'name_length');
  end if;

  select squads.owner_id
    into owner
  from public.sq8_squads as squads
  where squads.id = squad
  for update;

  if owner is null then
    return jsonb_build_object('ok', false, 'error', 'missing');
  end if;
  if me is distinct from owner then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;

  update public.sq8_squads
  set name = trimmed
  where id = squad;

  return jsonb_build_object('ok', true, 'error', null);
end;
$$;

revoke all on function sq8.rename_squad(uuid, text) from public, anon, authenticated;

create or replace function public.sq8_rename_squad(squad uuid, new_name text)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select sq8.rename_squad(squad, new_name);
$$;

revoke all on function public.sq8_rename_squad(uuid, text) from public, anon;
grant execute on function public.sq8_rename_squad(uuid, text) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_squads'
  ) then
    alter publication supabase_realtime add table public.sq8_squads;
  end if;
end $$;

-- down
-- revoke all on function public.sq8_rename_squad(uuid, text) from authenticated;
-- drop function if exists public.sq8_rename_squad(uuid, text);
-- drop function if exists sq8.rename_squad(uuid, text);
-- alter publication supabase_realtime drop table public.sq8_squads;
-- The name column from 0018 stays. A renamed value is not restored.
