#!/usr/bin/env bash
# Create a worktree for one Workstream B stream (docs/handoff/B_PLAN.md):
#   scripts/worktree.sh <stream>      e.g. accounts → ../Celia.ai-wt/accounts on branch georgi/b-accounts
# Branches from georgi/integration, copies the gitignored local config, installs ohpm packages.
set -euo pipefail
stream="${1:?usage: scripts/worktree.sh <stream>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WT="$(dirname "$ROOT")/Celia.ai-wt/$stream"
BRANCH="georgi/b-$stream"

if [ -d "$WT" ]; then
  echo "Exists: $WT"
else
  mkdir -p "$(dirname "$WT")"
  git -C "$ROOT" worktree add "$WT" -b "$BRANCH" georgi/integration
fi

CFG="app/entry/src/main/ets/common/LocalConfig.ets"
[ -f "$ROOT/$CFG" ] && cp "$ROOT/$CFG" "$WT/$CFG"
[ -f "$ROOT/watch/.env" ] && cp "$ROOT/watch/.env" "$WT/watch/.env"

source "$ROOT/app/env.sh"
(cd "$WT/app" && ohpm install >/dev/null)
(cd "$WT/watch" && ohpm install >/dev/null)
echo "Ready: $WT  (branch $BRANCH)"
