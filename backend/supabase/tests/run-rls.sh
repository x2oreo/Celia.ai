#!/usr/bin/env bash
# Applies every migration to a throw-away local Postgres (with supabase-shim.sql) and runs accounts_rls.sql.
# Needs a local Postgres 15+ (`brew install postgresql@15`); nothing touches the real project.
#   backend/supabase/tests/run-rls.sh        → prints ALL ACCOUNTS RLS CHECKS PASSED or the failing check
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${PG_BIN:-$(dirname "$(command -v initdb 2>/dev/null || echo /opt/homebrew/opt/postgresql@15/bin/initdb)")}"
WORK="$(mktemp -d /tmp/celia-rls.XXXX)"
PORT="${PG_PORT:-55433}"
trap '"$BIN/pg_ctl" -D "$WORK/db" stop -m fast >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
"$BIN/initdb" -D "$WORK/db" -U postgres -A trust >/dev/null
"$BIN/pg_ctl" -D "$WORK/db" -o "-p $PORT -k $WORK" -l "$WORK/log" start >/dev/null
export PGOPTIONS="-c client_min_messages=warning"
PSQL=("$BIN/psql" -h "$WORK" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -c "create database t" >/dev/null
"${PSQL[@]}" -d t -f "$HERE/supabase-shim.sql" >/dev/null
for f in $(ls "$HERE/../migrations/"*.sql | sort); do
  sed 's/create extension if not exists pg_net;//' "$f" | "${PSQL[@]}" -d t >/dev/null 2>&1 || { echo "migration failed: $f"; exit 1; }
done
"${PSQL[@]}" -d t -f "$HERE/accounts_rls.sql" 2>&1 | grep -E "FAILED|ERROR|PASSED" || true
