#!/usr/bin/env bash
# Build → install → launch → screenshot for the watch app. Run from anywhere:  watch/scripts/run.sh [screenshot-path]
# Needs the Huawei_Wearable emulator (or a watch) running. With the phone emulator also connected, the wearable
# target is picked by device type; set WATCH_TARGET=<serial> to choose one yourself (`hdc list targets`).
#   --no-build   install the HAP that is already built
set -euo pipefail

WATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CALLER_DIR="$(pwd)"

BUNDLE="ai.celia.watch"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
BUILD=1
SHOT=""
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    *) SHOT="$arg" ;;
  esac
done
SHOT="${SHOT:-$WATCH_DIR/build/screenshot.jpeg}"
case "$SHOT" in /*) ;; *) SHOT="$CALLER_DIR/$SHOT" ;; esac
cd "$WATCH_DIR"
source ./env.sh

# The wearable is the target whose device type says so; the phone emulator is skipped.
TARGET="${WATCH_TARGET:-}"
if [ -z "$TARGET" ]; then
  for t in $(hdc list targets | tr -d '\r' | grep -v -e '^\[Empty\]' -e '^$' || true); do
    if [ "$(hdc -t "$t" shell param get const.product.devicetype | tr -d '\r\n ')" = "wearable" ]; then
      TARGET="$t"
      break
    fi
  done
fi
if [ -z "$TARGET" ]; then
  echo "No wearable target. Start it: \$DEVECO/tools/emulator/Emulator -hvd Huawei_Wearable" >&2
  exit 1
fi
echo "Watch target: $TARGET"

if [ "$BUILD" -eq 1 ]; then
  hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
fi
if [ ! -f "$HAP" ]; then
  # The emulator installs unsigned HAPs; a real watch needs signing (README → Setup).
  HAP="entry/build/default/outputs/default/entry-default-unsigned.hap"
  echo "No signed HAP - installing the unsigned one (emulator only)." >&2
fi

hdc -t "$TARGET" install -r "$HAP"
hdc -t "$TARGET" shell aa force-stop "$BUNDLE" || true
hdc -t "$TARGET" shell aa start -a EntryAbility -b "$BUNDLE"
sleep 3

mkdir -p "$(dirname "$SHOT")"
hdc -t "$TARGET" shell snapshot_display -f /data/local/tmp/celia-watch.jpeg
hdc -t "$TARGET" file recv /data/local/tmp/celia-watch.jpeg "$SHOT"
echo "Screenshot: $SHOT"
