#!/usr/bin/env bash
# Two sessions join one code when the squad already has 7 people.
# The squad row lock must leave exactly 8. Not the live project.
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

OWNER='e3000000-0000-4000-8000-000000000001'
A8='e3000000-0000-4000-8000-000000000008'
A9='e3000000-0000-4000-8000-000000000009'

psql -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, email) values
  ('$OWNER', 'race-owner@example.com'),
  ('e3000000-0000-4000-8000-000000000002', 'race2@example.com'),
  ('e3000000-0000-4000-8000-000000000003', 'race3@example.com'),
  ('e3000000-0000-4000-8000-000000000004', 'race4@example.com'),
  ('e3000000-0000-4000-8000-000000000005', 'race5@example.com'),
  ('e3000000-0000-4000-8000-000000000006', 'race6@example.com'),
  ('e3000000-0000-4000-8000-000000000007', 'race7@example.com'),
  ('$A8', 'race8@example.com'),
  ('$A9', 'race9@example.com');

insert into public.sq8_squads (id, owner_id)
values ('e3100000-0000-4000-8000-000000000001', '$OWNER');

insert into public.sq8_squad_members (squad_id, user_id)
select 'e3100000-0000-4000-8000-000000000001', id
from auth.users
where email like 'race%@example.com'
  and email not in ('race8@example.com', 'race9@example.com', 'race-owner@example.com');

insert into public.sq8_invites (squad_id, code, created_by, expires_at, max_uses)
values (
  'e3100000-0000-4000-8000-000000000001',
  'RACE2345',
  '$OWNER',
  now() + interval '1 day',
  7
);
SQL

join_as() {
  local user_id="$1"
  psql -v ON_ERROR_STOP=1 -tA <<SQL
begin;
select set_config('request.jwt.claim.sub', '$user_id', false);
set role authenticated;
select public.sq8_join_with_code('RACE2345');
select pg_sleep(2);
commit;
SQL
}

join_as "$A8" >"$tmp/a.out" 2>&1 &
pid_a=$!
join_as "$A9" >"$tmp/b.out" 2>&1 &
pid_b=$!
set +e
wait "$pid_a"
status_a=$?
wait "$pid_b"
status_b=$?
set -e

if [ "$status_a" -ne 0 ] || [ "$status_b" -ne 0 ]; then
  echo "invite race session failed a=$status_a b=$status_b" >&2
  echo "---- a ----" >&2
  cat "$tmp/a.out" >&2
  echo "---- b ----" >&2
  cat "$tmp/b.out" >&2
  exit 1
fi

ok_n="$(cat "$tmp/a.out" "$tmp/b.out" | grep -c '"ok": true' || true)"
full_n="$(cat "$tmp/a.out" "$tmp/b.out" | grep -c '"error": "full"' || true)"
members="$(psql -tA -c "select count(*) from public.sq8_squad_members where squad_id = 'e3100000-0000-4000-8000-000000000001'")"

if [ "$ok_n" != "1" ] || [ "$full_n" != "1" ] || [ "$members" != "8" ]; then
  echo "expected one join and one full at 8 members, got ok=$ok_n full=$full_n members=$members" >&2
  echo "---- a ----" >&2
  cat "$tmp/a.out" >&2
  echo "---- b ----" >&2
  cat "$tmp/b.out" >&2
  exit 1
fi

echo "sq8 invite race stopped at 8"
