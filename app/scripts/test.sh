#!/usr/bin/env bash
# Run local unit tests (entry/src/test, no device needed) and print the summary.
# Exit code is non-zero when the build or any test fails.
set -uo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"
source ./env.sh

RESULT="entry/.test/default/intermediates/test/coverage_data/test_result.txt"
rm -f "$RESULT"   # never show a stale result from an earlier run

hvigorw --mode module -p module=entry@default -p product=default test --no-daemon
STATUS=$?

if [ -f "$RESULT" ]; then
  cat "$RESULT"
else
  echo "No test result produced (build failed before tests ran)." >&2
fi
exit "$STATUS"
