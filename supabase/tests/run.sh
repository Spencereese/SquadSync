#!/usr/bin/env bash
# Applies the slice 2 migrations to whatever database PG* points at, then
# runs the local RLS checks. Point this at a throwaway Postgres only.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

psql -v ON_ERROR_STOP=1 -f "$root/tests/00_harness.sql"
psql -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0001_profiles.sql"
psql -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0002_squad_members.sql"
psql -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0003_messages.sql"
psql -v ON_ERROR_STOP=1 -f "$root/migrations/20261103_0004_read_state.sql"
psql -v ON_ERROR_STOP=1 -f "$root/migrations/20261108_0005_own_profile_and_squad_guard.sql"
psql -v ON_ERROR_STOP=1 -f "$root/migrations/20261108_0006_check_ins.sql"
psql -v ON_ERROR_STOP=1 -f "$root/tests/sq8_rls.sql"
psql -v ON_ERROR_STOP=1 -f "$root/tests/sq8_recovery.sql"
psql -v ON_ERROR_STOP=1 -f "$root/tests/sq8_check_ins.sql"
bash "$root/tests/sq8_concurrency.sh"

echo "sq8 sql tests passed"
