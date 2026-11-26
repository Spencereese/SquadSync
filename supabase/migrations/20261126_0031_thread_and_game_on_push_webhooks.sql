-- 0031: push webhooks for side-thread replies and Game on.
--
-- LIVE: applied on sfckxrnoiwetmzdycqaa on Nov 26, 2026 by Grok Bot as migration
-- version 20261126141715, name "sq8_thread_and_game_on_push_webhooks"
-- (supabase_migrations.schema_migrations). This file is that SQL, unchanged, so the
-- repo and live line up. A read-only catalog check the same day matched the live
-- function and trigger definitions to this text.
--
-- Mirrors the live sq8_messages_push trigger (AFTER INSERT ON public.sq8_messages,
-- EXECUTE FUNCTION sq8.notify_message_push()), which was set up outside this repo:
-- security definer, empty search_path, the webhook secret read by name from Vault
-- (sq8_push_webhook_secret) at call time, sent in x-sq8-webhook-secret, 5 s timeout,
-- a no-op without the secret, and a failure is a warning that never blocks the insert.
-- No secret value is in this file. Needs Vault and pg_net, so supabase/tests/run.sh
-- does not apply it locally.
--
-- Two more push webhooks for sq8-notify-message, wired exactly like
-- sq8_messages_push / sq8.notify_message_push: same URL, same vault secret
-- (sq8_push_webhook_secret) in x-sq8-webhook-secret, same 5 s timeout, no-op
-- when the secret is missing, and never blocks the insert.

create or replace function sq8.notify_thread_message_push()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  hook_secret text;
begin
  select decrypted_secret into hook_secret
  from vault.decrypted_secrets
  where name = 'sq8_push_webhook_secret'
  limit 1;
  if hook_secret is null then
    return new;
  end if;
  perform net.http_post(
    url := 'https://sfckxrnoiwetmzdycqaa.supabase.co/functions/v1/sq8-notify-message',
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'sq8_thread_messages',
      'schema', 'public',
      'record', jsonb_build_object(
        'id', new.id,
        'thread_id', new.thread_id,
        'squad_id', new.squad_id,
        'sender_id', new.sender_id,
        'body', new.body
      ),
      'old_record', null
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-sq8-webhook-secret', hook_secret
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  raise warning 'sq8_notify_thread_message_push failed: %', sqlstate;
  return new;
end;
$$;

create or replace function sq8.notify_game_on_push()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  hook_secret text;
begin
  select decrypted_secret into hook_secret
  from vault.decrypted_secrets
  where name = 'sq8_push_webhook_secret'
  limit 1;
  if hook_secret is null then
    return new;
  end if;
  perform net.http_post(
    url := 'https://sfckxrnoiwetmzdycqaa.supabase.co/functions/v1/sq8-notify-message',
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'sq8_spot_calls',
      'schema', 'public',
      'record', jsonb_build_object(
        'id', new.id,
        'squad_id', new.squad_id,
        'caller_id', new.caller_id,
        'kind', new.kind,
        'game', new.game,
        'seat_target', new.seat_target
      ),
      'old_record', null
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-sq8-webhook-secret', hook_secret
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  raise warning 'sq8_notify_game_on_push failed: %', sqlstate;
  return new;
end;
$$;

revoke all on function sq8.notify_thread_message_push() from public, anon, authenticated;
revoke all on function sq8.notify_game_on_push() from public, anon, authenticated;

drop trigger if exists sq8_thread_messages_push on public.sq8_thread_messages;
create trigger sq8_thread_messages_push
  after insert on public.sq8_thread_messages
  for each row execute function sq8.notify_thread_message_push();

drop trigger if exists sq8_spot_calls_push on public.sq8_spot_calls;
create trigger sq8_spot_calls_push
  after insert on public.sq8_spot_calls
  for each row execute function sq8.notify_game_on_push();
