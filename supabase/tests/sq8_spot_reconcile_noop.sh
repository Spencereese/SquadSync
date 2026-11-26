#!/usr/bin/env bash
# 0027 is meant to be a no-op on live. Here, on a database built the way live
# was (0013, then 0020), the spot tables' catalog must be identical before and
# after applying it twice. Not the live project.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

snapshot() {
  psql -tA <<'SQL'
select string_agg(line, E'\n' order by line) from (
  select 'col ' || table_name || '.' || column_name || ' ' || data_type || ' ' || is_nullable || ' ' || coalesce(column_default, '') as line
  from information_schema.columns where table_schema = 'public' and table_name like 'sq8_spot%'
  union all
  select 'con ' || conname || ' ' || oid::text || ' ' || pg_get_constraintdef(oid)
  from pg_constraint where conrelid::regclass::text like '%sq8_spot%'
  union all
  select 'trg ' || tgname || ' ' || oid::text from pg_trigger
  where not tgisinternal and tgrelid::regclass::text like '%sq8_spot%'
  union all
  select 'fn ' || p.oid::regprocedure::text || ' ' || md5(pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'sq8') and p.proname like '%spot%'
) as catalog;
SQL
}

before="$(snapshot)"
psql -v ON_ERROR_STOP=1 -q -f "$root/migrations/20261126_0027_spot_reconcile.sql"
psql -v ON_ERROR_STOP=1 -q -f "$root/migrations/20261126_0027_spot_reconcile.sql"
after="$(snapshot)"
if [ "$before" != "$after" ]; then
  echo "0027 changed the spot catalog:" >&2
  diff <(echo "$before") <(echo "$after") >&2 || true
  exit 1
fi
echo "sq8 0027 is a no-op on a live-shaped database"
