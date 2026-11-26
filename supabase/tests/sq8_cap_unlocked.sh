#!/usr/bin/env bash
# Throwaway proof that file 2 does not lock the member cap, and that two
# owner creates are already one squad without file 5. Does not apply file 5
# and does not touch a live project.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
db="${SQ8_CAP_DB:-sq8_cap_unlocked}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

dropdb --if-exists "$db"
createdb "$db"

psql_db() {
  PGDATABASE="$db" psql "$@"
}

psql_db -v ON_ERROR_STOP=1 -f "$root/tests/00_harness.sql"
psql_db -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0001_profiles.sql"
psql_db -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0002_squad_members.sql"
psql_db -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0003_messages.sql"
psql_db -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0004_read_state.sql"

OWNER='d0000000-0000-4000-8000-000000000001'
A8='d0000000-0000-4000-8000-000000000008'
A9='d0000000-0000-4000-8000-000000000009'

psql_db -v ON_ERROR_STOP=1 <<SQL
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
  psql_db -v ON_ERROR_STOP=1 <<SQL
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
  echo "without file 5, expected one owner create, got $wins" >&2
  echo "---- session a ($status_a) ----" >&2
  cat "$tmp/create-a.out" >&2
  echo "---- session b ($status_b) ----" >&2
  cat "$tmp/create-b.out" >&2
  exit 1
fi

squads="$(psql_db -tA -c "select count(*) from public.sq8_squads where owner_id = '$OWNER'")"
if [ "$squads" != "1" ]; then
  echo "without file 5, owner create left $squads squads" >&2
  exit 1
fi

psql_db -v ON_ERROR_STOP=1 <<SQL
insert into public.sq8_squad_members (squad_id, user_id)
select s.id, u.id
from public.sq8_squads s
join auth.users u on u.email like 'm%@example.com'
  and u.email not in ('m8@example.com', 'm9@example.com')
where s.owner_id = '$OWNER';
SQL

filled="$(psql_db -tA -c "select count(*) from public.sq8_squad_members m join public.sq8_squads s on s.id = m.squad_id where s.owner_id = '$OWNER'")"
if [ "$filled" != "7" ]; then
  echo "expected 7 members before the unlocked cap race, found $filled" >&2
  exit 1
fi

add_member() {
  local user_id="$1"
  psql_db -v ON_ERROR_STOP=1 <<SQL
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
final="$(psql_db -tA -c "select count(*) from public.sq8_squad_members m join public.sq8_squads s on s.id = m.squad_id where s.owner_id = '$OWNER'")"

# File 2 counts without locking the squad row. Both sessions can see 7 and commit.
if [ "$wins" -ne 2 ] || [ "$final" != "9" ]; then
  echo "expected the unlocked cap to reach 9 members from two commits, got wins=$wins final=$final" >&2
  echo "---- seat a ($status_a) ----" >&2
  cat "$tmp/add-a.out" >&2
  echo "---- seat b ($status_b) ----" >&2
  cat "$tmp/add-b.out" >&2
  exit 1
fi

echo "sq8 unlocked cap: owner creates stayed 1, member race reached 9"
dropdb --if-exists "$db"
