#!/usr/bin/env bash
# Two real sessions against the throwaway database. Not the live project.
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

OWNER='d0000000-0000-4000-8000-000000000001'
SQUAD='d1000000-0000-4000-8000-000000000001'
A8='d0000000-0000-4000-8000-000000000008'
A9='d0000000-0000-4000-8000-000000000009'

psql -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, email) values
  ('$OWNER', 'owner-race@example.com'),
  ('d0000000-0000-4000-8000-000000000002', 'm2@example.com'),
  ('d0000000-0000-4000-8000-000000000003', 'm3@example.com'),
  ('d0000000-0000-4000-8000-000000000004', 'm4@example.com'),
  ('d0000000-0000-4000-8000-000000000005', 'm5@example.com'),
  ('d0000000-0000-4000-8000-000000000006', 'm6@example.com'),
  ('d0000000-0000-4000-8000-000000000007', 'm7@example.com'),
  ('$A8', 'm8@example.com'),
  ('$A9', 'm9@example.com');
SQL

create_squad() {
  psql -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claim.sub', '$OWNER', false);
set role authenticated;
insert into public.sq8_squads (owner_id) values ('$OWNER');
select pg_sleep(2);
commit;
SQL
}

create_squad >"$tmp/create-a.out" 2>&1 &
pid_a=$!
create_squad >"$tmp/create-b.out" 2>&1 &
pid_b=$!
set +e
wait "$pid_a"
status_a=$?
wait "$pid_b"
status_b=$?
set -e

wins=0
if [ "$status_a" -eq 0 ]; then wins=$((wins + 1)); fi
if [ "$status_b" -eq 0 ]; then wins=$((wins + 1)); fi
if [ "$wins" -ne 1 ]; then
  echo "expected exactly one owner create to commit, got $wins" >&2
  echo "---- session a ($status_a) ----" >&2
  cat "$tmp/create-a.out" >&2
  echo "---- session b ($status_b) ----" >&2
  cat "$tmp/create-b.out" >&2
  exit 1
fi

squads="$(psql -tA -c "select count(*) from public.sq8_squads where owner_id = '$OWNER'")"
members="$(psql -tA -c "select count(*) from public.sq8_squad_members where user_id = '$OWNER'")"
if [ "$squads" != "1" ] || [ "$members" != "1" ]; then
  echo "owner ended with squads=$squads memberships=$members" >&2
  exit 1
fi

# Fill that one squad to seven, then race the eighth and ninth seats.
psql -v ON_ERROR_STOP=1 <<SQL
insert into public.sq8_squad_members (squad_id, user_id)
select s.id, u.id
from public.sq8_squads s
join auth.users u on u.email like 'm%@example.com'
  and u.email not in ('m8@example.com', 'm9@example.com')
where s.owner_id = '$OWNER';
SQL

filled="$(psql -tA -c "select count(*) from public.sq8_squad_members m join public.sq8_squads s on s.id = m.squad_id where s.owner_id = '$OWNER'")"
if [ "$filled" != "7" ]; then
  echo "expected 7 members before the cap race, found $filled" >&2
  exit 1
fi

add_member() {
  local user_id="$1"
  psql -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claim.sub', '$OWNER', false);
set role authenticated;
insert into public.sq8_squad_members (squad_id, user_id)
select id, '$user_id' from public.sq8_squads where owner_id = '$OWNER';
select pg_sleep(2);
commit;
SQL
}

add_member "$A8" >"$tmp/add-a.out" 2>&1 &
pid_a=$!
add_member "$A9" >"$tmp/add-b.out" 2>&1 &
pid_b=$!
set +e
wait "$pid_a"
status_a=$?
wait "$pid_b"
status_b=$?
set -e

wins=0
if [ "$status_a" -eq 0 ]; then wins=$((wins + 1)); fi
if [ "$status_b" -eq 0 ]; then wins=$((wins + 1)); fi
if [ "$wins" -ne 1 ]; then
  echo "expected exactly one of the last two seats to commit, got $wins" >&2
  echo "---- seat a ($status_a) ----" >&2
  cat "$tmp/add-a.out" >&2
  echo "---- seat b ($status_b) ----" >&2
  cat "$tmp/add-b.out" >&2
  exit 1
fi

final="$(psql -tA -c "select count(*) from public.sq8_squad_members m join public.sq8_squads s on s.id = m.squad_id where s.owner_id = '$OWNER'")"
if [ "$final" != "8" ]; then
  echo "cap race ended at $final members, expected 8" >&2
  exit 1
fi

echo "sq8 concurrency tests passed"
