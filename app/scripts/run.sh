#!/usr/bin/env bash
# Build → install → launch → screenshot. Run from anywhere:  app/scripts/run.sh [screenshot-path]
# Needs a running emulator/device (`hdc list targets`). A real device also needs a signing config (README → Signing).
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"
source ./env.sh
# With the watch emulator also attached, plain hdc refuses to pick a device: HDC_TARGET=127.0.0.1:5555 picks one.
hdc() { command hdc ${HDC_TARGET:+-t "$HDC_TARGET"} "$@"; }

BUNDLE="com.celiaai.app"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
SHOT="${1:-$APP_DIR/build/screenshot.jpeg}"

hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
if [ ! -f "$HAP" ]; then
  # The emulator installs unsigned HAPs; a real device needs signing (README → Signing).
  HAP="entry/build/default/outputs/default/entry-default-unsigned.hap"
  echo "No signed HAP - installing the unsigned one (emulator only)." >&2
fi

hdc install -r "$HAP"
hdc shell aa force-stop "$BUNDLE" || true
hdc shell aa start -a EntryAbility -b "$BUNDLE"
sleep 2

mkdir -p "$(dirname "$SHOT")"
hdc shell snapshot_display -f /data/local/tmp/celia.jpeg
hdc file recv /data/local/tmp/celia.jpeg "$SHOT"
echo "Screenshot: $SHOT"
