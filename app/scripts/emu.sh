#!/usr/bin/env bash
# One emulator, several worktrees: take the lock before install / launch / screenshot, release it right after.
#   app/scripts/emu.sh up              start the phone emulator when hdc sees no device
#   app/scripts/emu.sh lock <who>      wait for the lock (a lock older than 15 min is taken over)
#   app/scripts/emu.sh unlock          release it
#   app/scripts/emu.sh who             print the holder, if any
set -uo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$APP_DIR/env.sh"

LOCK="/tmp/celia-emu.lock"
STALE_S=900
WAIT_S=1200

case "${1:-}" in
  up)
    if hdc list targets | grep -q "127.0.0.1"; then
      echo "Emulator already up."
      exit 0
    fi
    nohup "$DEVECO/tools/emulator/Emulator" -hvd "Pura 90" >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
      sleep 3
      if hdc list targets | grep -q "127.0.0.1"; then
        echo "Emulator up."
        exit 0
      fi
    done
    echo "Emulator did not show up in hdc after 3 minutes." >&2
    exit 1
    ;;
  lock)
    WHO="${2:?usage: emu.sh lock <who>}"
    START=$(date +%s)
    while ! mkdir "$LOCK" 2>/dev/null; do
      NOW=$(date +%s)
      AGE=$(( NOW - $(stat -f %m "$LOCK" 2>/dev/null || echo "$NOW") ))
      if [ "$AGE" -gt "$STALE_S" ]; then
        echo "Taking over a stale lock held by $(cat "$LOCK/who" 2>/dev/null)." >&2
        rm -rf "$LOCK"
        continue
      fi
      if [ $(( NOW - START )) -gt "$WAIT_S" ]; then
        echo "Gave up waiting for the emulator (held by $(cat "$LOCK/who" 2>/dev/null))." >&2
        exit 1
      fi
      sleep 5
    done
    echo "$WHO" > "$LOCK/who"
    echo "Emulator locked by $WHO."
    ;;
  unlock)
    rm -rf "$LOCK"
    echo "Emulator released."
    ;;
  who)
    cat "$LOCK/who" 2>/dev/null || echo "free"
    ;;
  *)
    echo "usage: emu.sh up | lock <who> | unlock | who" >&2
    exit 2
    ;;
esac
