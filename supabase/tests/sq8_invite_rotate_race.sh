#!/usr/bin/env bash
# A rotate and a join of the code it replaces, several times.
# Neither session may deadlock. The join uses only the code from before the
# rotate, so it either takes that seat or comes back invalid. Not the live project.
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

OWNER='c4000000-0000-4000-8000-000000000001'
JOINER='c4000000-0000-4000-8000-000000000002'
SQUAD='c4100000-0000-4000-8000-000000000001'

psql -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, email) values
  ('$OWNER', 'rotate-owner@example.com'),
  ('$JOINER', 'rotate-joiner@example.com');

insert into public.sq8_squads (id, owner_id)
values ('$SQUAD', '$OWNER');
SQL

codes=(TURN234A TURN234B TURN234C TURN234D TURN234E TURN234F TURN234G TURN234H)
ok_rounds=0
invalid_rounds=0

run_sql() {
  psql -v ON_ERROR_STOP=1 -tA -c "set statement_timeout = '20s'" -c "$1"
}

for i in "${!codes[@]}"; do
  code="${codes[$i]}"
  psql -v ON_ERROR_STOP=1 <<SQL
delete from public.sq8_squad_members
where squad_id = '$SQUAD'
  and user_id = '$JOINER';

update public.sq8_invites
set revoked_at = now()
where squad_id = '$SQUAD'
  and revoked_at is null;

insert into public.sq8_invites (
  squad_id, code, created_by, expires_at, max_uses
) values (
  '$SQUAD',
  '$code',
  '$OWNER',
  now() + interval '1 day',
  8
);
SQL

  join_session() {
    psql -v ON_ERROR_STOP=1 -tA <<SQL
begin;
set statement_timeout = '20s';
select set_config('request.jwt.claim.sub', '$JOINER', false);
set role authenticated;
select public.sq8_join_with_code('$code');
select pg_sleep(0.3);
commit;
SQL
  }

  rotate_session() {
    psql -v ON_ERROR_STOP=1 -tA <<SQL
begin;
set statement_timeout = '20s';
select set_config('request.jwt.claim.sub', '$OWNER', false);
set role authenticated;
select public.sq8_create_invite();
select pg_sleep(0.3);
commit;
SQL
  }

  if (( i % 2 == 0 )); then
    join_session >"$tmp/join.out" 2>&1 &
    pid_join=$!
    sleep 0.05
    rotate_session >"$tmp/rotate.out" 2>&1 &
    pid_rotate=$!
  else
    rotate_session >"$tmp/rotate.out" 2>&1 &
    pid_rotate=$!
    sleep 0.05
    join_session >"$tmp/join.out" 2>&1 &
    pid_join=$!
  fi

  set +e
  wait "$pid_join"
  status_join=$?
  wait "$pid_rotate"
  status_rotate=$?
  set -e

  if [ "$status_join" -ne 0 ] || [ "$status_rotate" -ne 0 ]; then
    echo "rotate/join round $code deadlocked or failed join=$status_join rotate=$status_rotate" >&2
    echo "---- join ----" >&2
    cat "$tmp/join.out" >&2
    echo "---- rotate ----" >&2
    cat "$tmp/rotate.out" >&2
    exit 1
  fi

  ok_n="$(grep -c '"ok": true' "$tmp/join.out" || true)"
  invalid_n="$(grep -c '"error": "invalid"' "$tmp/join.out" || true)"
  members="$(psql -tA -c "select count(*) from public.sq8_squad_members where squad_id = '$SQUAD' and user_id = '$JOINER'")"
  revoked="$(psql -tA -c "select revoked_at is not null from public.sq8_invites where code = '$code'")"

  if [ "$ok_n" = "1" ] && [ "$invalid_n" = "0" ] && [ "$members" = "1" ]; then
    ok_rounds=$((ok_rounds + 1))
  elif [ "$ok_n" = "0" ] && [ "$invalid_n" = "1" ] && [ "$members" = "0" ]; then
    invalid_rounds=$((invalid_rounds + 1))
  else
    echo "round $code was neither a seat on the old code nor invalid: ok=$ok_n invalid=$invalid_n members=$members" >&2
    echo "---- join ----" >&2
    cat "$tmp/join.out" >&2
    echo "---- rotate ----" >&2
    cat "$tmp/rotate.out" >&2
    exit 1
  fi

  if [ "$revoked" != "t" ]; then
    echo "round $code left the old code active after the rotate" >&2
    exit 1
  fi
done

if [ "$ok_rounds" -lt 1 ] || [ "$invalid_rounds" -lt 1 ]; then
  echo "expected both a successful old-code join and an invalid join, got ok=$ok_rounds invalid=$invalid_rounds" >&2
  exit 1
fi

echo "sq8 rotate/join race had no deadlock (ok=$ok_rounds invalid=$invalid_rounds)"
