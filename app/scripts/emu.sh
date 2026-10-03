#!/usr/bin/env bash
# One phone emulator, several worktrees: take the lock before installing or driving the UI, release it after.
#   emu.sh lock <who>     wait (up to 20 min) for the emulator, then hold it
#   emu.sh unlock         release it (only the holder should)
#   emu.sh status         who holds it and since when
# A lock older than 15 min is treated as abandoned and taken over.
set -euo pipefail
LOCK="/tmp/celia-emulator.lock"
STALE=900

age() { echo $(( $(date +%s) - $(stat -f %m "$LOCK") )); }

case "${1:-}" in
  lock)
    who="${2:?usage: emu.sh lock <who>}"
    waited=0
    until mkdir "$LOCK" 2>/dev/null; do
      if [ -d "$LOCK" ] && [ "$(age)" -gt "$STALE" ]; then
        echo "Stale lock held by $(cat "$LOCK/owner" 2>/dev/null) — taking over." >&2
        rm -rf "$LOCK"
        continue
      fi
      if [ "$waited" -ge 1200 ]; then
        echo "Emulator still busy ($(cat "$LOCK/owner" 2>/dev/null)) after 20 min." >&2
        exit 1
      fi
      [ $((waited % 60)) -eq 0 ] && echo "Emulator busy: $(cat "$LOCK/owner" 2>/dev/null). Waiting…" >&2
      sleep 5
      waited=$((waited + 5))
    done
    echo "$who $(date '+%H:%M:%S')" > "$LOCK/owner"
    echo "Emulator locked by $who." ;;
  unlock)
    rm -rf "$LOCK"
    echo "Emulator released." ;;
  status)
    if [ -d "$LOCK" ]; then echo "Held by $(cat "$LOCK/owner" 2>/dev/null), $(age) s ago."; else echo "Free."; fi ;;
  *)
    sed -n '2,6p' "$0"; exit 1 ;;
esac
