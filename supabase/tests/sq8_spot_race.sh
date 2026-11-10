#!/usr/bin/env bash
# Two people RSVP in when seven are already in. The squad lock stops at 8.
# The ninth member exists only because this test bypasses the member-cap
# trigger. Not the live project.
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

SQUAD='c7100000-0000-4000-8000-000000000001'
A8='c7000000-0000-4000-8000-000000000008'
A9='c7000000-0000-4000-8000-000000000009'

psql -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, email)
select
  ('c7000000-0000-4000-8000-00000000000' || n::text)::uuid,
  'spot-race-' || n::text || '@example.com'
from generate_series(1, 9) as n;

insert into public.sq8_squads (id, owner_id)
values ('$SQUAD', 'c7000000-0000-4000-8000-000000000001');

insert into public.sq8_squad_members (squad_id, user_id)
select '$SQUAD', id
from auth.users
where email like 'spot-race-%@example.com'
  and id not in (
    '$A8',
    '$A9',
    'c7000000-0000-4000-8000-000000000001'
  );

set session_replication_role = replica;
insert into public.sq8_squad_members (squad_id, user_id) values
  ('$SQUAD', '$A8'),
  ('$SQUAD', '$A9');
set session_replication_role = origin;

select set_config('request.jwt.claim.sub', 'c7000000-0000-4000-8000-000000000001', false);
set role authenticated;
select public.sq8_call_spot('$SQUAD', 'Halo', now());
reset role;
SQL

call_id="$(psql -tA -c "select id from public.sq8_spot_calls where squad_id = '$SQUAD' and closed_at is null")"

for n in 2 3 4 5 6 7; do
  psql -v ON_ERROR_STOP=1 <<SQL
select set_config('request.jwt.claim.sub', 'c7000000-0000-4000-8000-00000000000$n', false);
set role authenticated;
select public.sq8_rsvp_spot('$call_id', 'in');
reset role;
SQL
done

rsvp_as() {
  local user_id="$1"
  psql -v ON_ERROR_STOP=1 -tA <<SQL >"$2" 2>&1
begin;
select set_config('request.jwt.claim.sub', '$user_id', false);
set role authenticated;
select public.sq8_rsvp_spot('$call_id', 'in');
select pg_sleep(1);
commit;
SQL
}

set +e
rsvp_as "$A8" "$tmp/a.out" &
pid_a=$!
rsvp_as "$A9" "$tmp/b.out" &
pid_b=$!
wait "$pid_a"
wait "$pid_b"
set -e

ins="$(psql -tA -c "select count(*) from public.sq8_spot_rsvps where call_id = '$call_id' and response = 'in'")"
full_n="$(grep -h 'spot_full' "$tmp/a.out" "$tmp/b.out" | wc -l | tr -d ' ')"

if [ "$ins" != "8" ] || [ "$full_n" != "1" ]; then
  echo "spot race expected 8 in and one spot_full, got in=$ins full=$full_n" >&2
  echo "---- a ----" >&2
  cat "$tmp/a.out" >&2
  echo "---- b ----" >&2
  cat "$tmp/b.out" >&2
  exit 1
fi

echo "sq8 spot race stopped at 8"
