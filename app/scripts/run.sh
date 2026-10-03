#!/usr/bin/env bash
# Build → install → launch → screenshot. Run from anywhere:  app/scripts/run.sh [screenshot-path]
# Needs a running emulator/device (`hdc list targets`) and a signing config (see README → Signing).
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"
source ./env.sh

BUNDLE="com.celiaai.app"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
SHOT="${1:-$APP_DIR/build/screenshot.jpeg}"

hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
if [ ! -f "$HAP" ]; then
  echo "No signed HAP at $HAP — configure signing in DevEco first (README → Signing)." >&2
  exit 1
fi

hdc install -r "$HAP"
hdc shell aa force-stop "$BUNDLE" || true
hdc shell aa start -a EntryAbility -b "$BUNDLE"
sleep 2

mkdir -p "$(dirname "$SHOT")"
hdc shell snapshot_display -f /data/local/tmp/celia.jpeg
hdc file recv /data/local/tmp/celia.jpeg "$SHOT"
echo "Screenshot: $SHOT"
