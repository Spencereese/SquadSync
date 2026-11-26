#!/usr/bin/env bash
# 0028 under concurrency. Two people take the last seat of a Game on at the
# same time: one gets in, one gets game_on_full. Two people start a Game on
# when one is already open: one starts, one gets game_on_cap. Not the live project.
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

SQUAD='e9100000-0000-4000-8000-000000000001'

psql -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users (id, email)
select ('e9000000-0000-4000-8000-00000000000' || n::text)::uuid, 'gameon-race-' || n::text || '@example.com'
from generate_series(1, 5) as n;
insert into public.sq8_squads (id, owner_id) values ('$SQUAD', 'e9000000-0000-4000-8000-000000000001');
insert into public.sq8_squad_members (squad_id, user_id)
select '$SQUAD', id from auth.users
where email like 'gameon-race-%@example.com' and id <> 'e9000000-0000-4000-8000-000000000001';
SQL

call_id="$(psql -tA <<SQL | tail -1
select set_config('request.jwt.claim.sub', 'e9000000-0000-4000-8000-000000000001', false);
set role authenticated;
select public.sq8_start_game_on('$SQUAD', 'Warzone', 1);
SQL
)"

as_user() {
  local user_id="$1" statement="$2" out="$3"
  psql -v ON_ERROR_STOP=1 -tA >"$out" 2>&1 <<SQL
begin;
select set_config('request.jwt.claim.sub', '$user_id', false);
set role authenticated;
$statement;
select pg_sleep(1);
commit;
SQL
}

set +e
as_user e9000000-0000-4000-8000-000000000002 "select public.sq8_join_game_on('$call_id')" "$tmp/a.out" &
pid_a=$!
as_user e9000000-0000-4000-8000-000000000003 "select public.sq8_join_game_on('$call_id')" "$tmp/b.out" &
pid_b=$!
wait "$pid_a"; wait "$pid_b"
set -e

ins="$(psql -tA -c "select count(*) from public.sq8_spot_rsvps where call_id = '$call_id' and response = 'in'")"
full_n="$(grep -h 'game_on_full' "$tmp/a.out" "$tmp/b.out" | wc -l | tr -d ' ')"
if [ "$ins" != "2" ] || [ "$full_n" != "1" ]; then
  echo "game on seat race expected 2 in and one game_on_full, got in=$ins full=$full_n" >&2
  cat "$tmp/a.out" "$tmp/b.out" >&2
  exit 1
fi

set +e
as_user e9000000-0000-4000-8000-000000000004 "select public.sq8_start_game_on('$SQUAD', 'Halo', 1)" "$tmp/c.out" &
pid_c=$!
as_user e9000000-0000-4000-8000-000000000005 "select public.sq8_start_game_on('$SQUAD', 'Apex', 1)" "$tmp/d.out" &
pid_d=$!
wait "$pid_c"; wait "$pid_d"
set -e

open_n="$(psql -tA -c "select count(*) from public.sq8_spot_calls where squad_id = '$SQUAD' and kind = 'game_on' and closed_at is null")"
cap_n="$(grep -h 'game_on_cap' "$tmp/c.out" "$tmp/d.out" | wc -l | tr -d ' ')"
if [ "$open_n" != "2" ] || [ "$cap_n" != "1" ]; then
  echo "game on cap race expected 2 open and one game_on_cap, got open=$open_n cap=$cap_n" >&2
  cat "$tmp/c.out" "$tmp/d.out" >&2
  exit 1
fi

echo "sq8 game on races held: last seat once, cap of two"
