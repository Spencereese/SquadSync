-- Proposed. Not applied to the live project.
-- One row per signed-in person per device token. Idempotent.
-- Does not grant anon or public. The push sender is not this function:
-- sq8.message_push_targets is executable by service_role only, when that
-- role exists, and it is how a server lists tokens for the other members.

create table if not exists public.sq8_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.sq8_profiles (id) on delete cascade,
  token text not null,
  platform text not null,
  updated_at timestamptz not null default now(),
  constraint sq8_device_tokens_platform
    check (platform in ('ios', 'android')),
  constraint sq8_device_tokens_token_not_blank
    check (char_length(btrim(token)) > 0)
);

create unique index if not exists sq8_device_tokens_user_token
  on public.sq8_device_tokens (user_id, token);

alter table public.sq8_device_tokens enable row level security;
alter table public.sq8_device_tokens force row level security;

revoke all on public.sq8_device_tokens from public, anon;
grant select, insert, update, delete on public.sq8_device_tokens to authenticated;

drop policy if exists sq8_device_tokens_select_own on public.sq8_device_tokens;
create policy sq8_device_tokens_select_own
  on public.sq8_device_tokens
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists sq8_device_tokens_insert_own on public.sq8_device_tokens;
create policy sq8_device_tokens_insert_own
  on public.sq8_device_tokens
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists sq8_device_tokens_update_own on public.sq8_device_tokens;
create policy sq8_device_tokens_update_own
  on public.sq8_device_tokens
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists sq8_device_tokens_delete_own on public.sq8_device_tokens;
create policy sq8_device_tokens_delete_own
  on public.sq8_device_tokens
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.sq8_register_device_token(
  device_token text,
  device_platform text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'sq8_device_token_signed_out' using errcode = '42501';
  end if;
  if device_platform is null or device_platform not in ('ios', 'android') then
    raise exception 'sq8_device_token_platform' using errcode = '22023';
  end if;
  if device_token is null or char_length(btrim(device_token)) = 0 then
    raise exception 'sq8_device_token_blank' using errcode = '22023';
  end if;

  insert into public.sq8_device_tokens as registered (user_id, token, platform)
  values (me, btrim(device_token), device_platform)
  on conflict (user_id, token) do update
    set platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.sq8_register_device_token(text, text) from public, anon;
grant execute on function public.sq8_register_device_token(text, text) to authenticated;

-- The signed-in person drops only their own copy of a token. Sign-out uses this.
create or replace function public.sq8_unregister_device_token(device_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'sq8_device_token_signed_out' using errcode = '42501';
  end if;
  if device_token is null or char_length(btrim(device_token)) = 0 then
    raise exception 'sq8_device_token_blank' using errcode = '22023';
  end if;
  delete from public.sq8_device_tokens
  where user_id = me
    and token = btrim(device_token);
end;
$$;

revoke all on function public.sq8_unregister_device_token(text) from public, anon;
grant execute on function public.sq8_unregister_device_token(text) to authenticated;

-- FCM said this token is dead. The service role deletes every copy of it.
create or replace function public.sq8_drop_device_token(device_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if device_token is null or char_length(btrim(device_token)) = 0 then
    raise exception 'sq8_device_token_blank' using errcode = '22023';
  end if;
  delete from public.sq8_device_tokens
  where token = btrim(device_token);
end;
$$;

revoke all on function public.sq8_drop_device_token(text)
  from public, anon, authenticated;

create or replace function sq8.message_push_targets(
  squad uuid,
  sender uuid
)
returns table (user_id uuid, token text, platform text)
language sql
stable
security definer
set search_path = ''
as $$
  select tokens.user_id, tokens.token, tokens.platform
  from public.sq8_squad_members as members
  join public.sq8_device_tokens as tokens
    on tokens.user_id = members.user_id
  where members.squad_id = squad
    and members.user_id is distinct from sender;
$$;

revoke all on function sq8.message_push_targets(uuid, uuid) from public, anon, authenticated;

-- PostgREST exposes public. The wrapper stays revoked from authenticated
-- so a signed-in person cannot list other people's tokens.
create or replace function public.sq8_message_push_targets(
  squad uuid,
  sender uuid
)
returns table (user_id uuid, token text, platform text)
language sql
stable
security definer
set search_path = ''
as $$
  select targets.user_id, targets.token, targets.platform
  from sq8.message_push_targets(squad, sender) as targets;
$$;

revoke all on function public.sq8_message_push_targets(uuid, uuid)
  from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function public.sq8_message_push_targets(uuid, uuid) to service_role';
    execute 'grant execute on function public.sq8_drop_device_token(text) to service_role';
  end if;
end $$;
