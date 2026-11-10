#!/usr/bin/env bash
# Two RSVPs race the join_until boundary.
# The early transaction has already begun, and is waiting on the squad lock,
# before join_until is moved to one second ahead of the database clock.
# The late transaction begins after that instant and waits on the same lock.
# Whichever lock order they run in, the early one is in and the late one is
# spot_join_closed. Not the live project.
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

SQUAD='c7200000-0000-4000-8000-000000000001'
OWNER='c7300000-0000-4000-8000-000000000001'
EARLY='c7300000-0000-4000-8000-000000000002'
LATE='c7300000-0000-4000-8000-000000000003'

psql -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, email) values
  ('$OWNER', 'spot-expiry-owner@example.com'),
  ('$EARLY', 'spot-expiry-early@example.com'),
  ('$LATE', 'spot-expiry-late@example.com');

insert into public.sq8_squads (id, owner_id)
values ('$SQUAD', '$OWNER');

insert into public.sq8_squad_members (squad_id, user_id) values
  ('$SQUAD', '$EARLY'),
  ('$SQUAD', '$LATE');

select set_config('request.jwt.claim.sub', '$OWNER', false);
set role authenticated;
select public.sq8_call_spot('$SQUAD', 'Halo', now());
reset role;
SQL

call_id="$(psql -tA -c "select id from public.sq8_spot_calls where squad_id = '$SQUAD' and closed_at is null")"

psql -v ON_ERROR_STOP=1 >"$tmp/hold.out" 2>&1 <<SQL &
set application_name = 'sq8-spot-expiry-hold';
begin;
select id from public.sq8_squads where id = '$SQUAD' for update;
select pg_sleep(120);
commit;
SQL
hold_pid=$!

for _ in $(seq 1 50); do
  holding="$(psql -tA -c "select count(*) from pg_stat_activity where application_name = 'sq8-spot-expiry-hold' and state = 'active'")"
  if [[ "$holding" != "0" ]]; then
    break
  fi
  sleep 0.1
done
if [[ "${holding:-0}" == "0" ]]; then
  echo "the squad lock was not held" >&2
  exit 1
fi

psql -v ON_ERROR_STOP=1 >"$tmp/early.out" 2>&1 <<SQL &
set application_name = 'sq8-spot-expiry-early';
begin;
select set_config('request.jwt.claim.sub', '$EARLY', false);
set role authenticated;
select public.sq8_rsvp_spot('$call_id', 'in');
commit;
SQL
early_pid=$!

waiting=0
for _ in $(seq 1 50); do
  waiting="$(psql -tA -c "select count(*) from pg_stat_activity where application_name = 'sq8-spot-expiry-early' and wait_event_type = 'Lock'")"
  if [[ "$waiting" != "0" ]]; then
    break
  fi
  sleep 0.1
done
if [[ "$waiting" == "0" ]]; then
  echo "the early RSVP did not wait on the squad lock" >&2
  psql -c "select application_name, state, wait_event_type, wait_event, left(query, 120) from pg_stat_activity where application_name like 'sq8-spot-expiry-%'" >&2 || true
  cat "$tmp/early.out" >&2 || true
  exit 1
fi

psql -v ON_ERROR_STOP=1 -c "update public.sq8_spot_calls set join_until = clock_timestamp() + interval '1 second' where id = '$call_id'"
sleep 2

psql -v ON_ERROR_STOP=1 >"$tmp/late.out" 2>&1 <<SQL &
set application_name = 'sq8-spot-expiry-late';
begin;
select set_config('request.jwt.claim.sub', '$LATE', false);
set role authenticated;
select public.sq8_rsvp_spot('$call_id', 'in');
commit;
SQL
late_pid=$!

late_waiting=0
for _ in $(seq 1 50); do
  late_waiting="$(psql -tA -c "select count(*) from pg_stat_activity where application_name = 'sq8-spot-expiry-late' and wait_event_type = 'Lock'")"
  if [[ "$late_waiting" != "0" ]]; then
    break
  fi
  sleep 0.1
done
if [[ "$late_waiting" == "0" ]]; then
  echo "the late RSVP did not wait on the squad lock" >&2
  cat "$tmp/late.out" >&2 || true
  exit 1
fi

hold_backend="$(psql -tA -c "select pid from pg_stat_activity where application_name = 'sq8-spot-expiry-hold' limit 1")"
psql -v ON_ERROR_STOP=1 -c "select pg_cancel_backend($hold_backend)" >/dev/null

set +e
wait "$hold_pid"
wait "$early_pid"
early_code=$?
wait "$late_pid"
late_code=$?
set -e

early_in="$(psql -tA -c "select count(*) from public.sq8_spot_rsvps where call_id = '$call_id' and user_id = '$EARLY' and response = 'in'")"
late_in="$(psql -tA -c "select count(*) from public.sq8_spot_rsvps where call_id = '$call_id' and user_id = '$LATE' and response = 'in'")"
closed_n="$(grep -c 'spot_join_closed' "$tmp/late.out" || true)"

if [[ "$early_code" != "0" || "$early_in" != "1" || "$late_in" != "0" || "$closed_n" != "1" ]]; then
  echo "early_code=$early_code late_code=$late_code early_in=$early_in late_in=$late_in closed_n=$closed_n" >&2
  echo '--- early ---' >&2
  cat "$tmp/early.out" >&2 || true
  echo '--- late ---' >&2
  cat "$tmp/late.out" >&2 || true
  exit 1
fi

echo "sq8 spot expiry race kept the early RSVP and refused the late one"
