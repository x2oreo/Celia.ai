#!/usr/bin/env bash
# Real phone: preflight → build → install → launch → screenshot. Full guide: docs/REAL_DEVICE.md
#   app/scripts/device.sh           check everything, then build and install on the connected phone
#   app/scripts/device.sh check     preflight only (no build, nothing installed)
#   app/scripts/device.sh udid      print the phone's UDID (for a manual AppGallery Connect profile)
# Several devices connected: HDC_TARGET=<serial> app/scripts/device.sh
set -uo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"
source ./env.sh

BUNDLE="com.celiaai.app"
MIN_API=20
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
CONFIG="entry/src/main/ets/common/LocalConfig.ets"
SHOT="$APP_DIR/build/device-screenshot.jpeg"
MODE="${1:-install}"

problems=0
ok()   { echo "  ok    $1"; }
warn() { echo "  warn  $1"; }
bad()  { echo "  FAIL  $1"; problems=$((problems + 1)); }

echo "Preflight"

# 1. A real phone, not the emulator (the emulator shows up as 127.0.0.1:<port>).
TARGET="${HDC_TARGET:-}"
if [ -z "$TARGET" ]; then
  PHONES="$(hdc list targets | tr -d '\r' | grep -v -e '^127\.0\.0\.1' -e '^\[Empty\]' -e '^$' || true)"
  COUNT="$(printf '%s' "$PHONES" | grep -c . || true)"
  if [ "$COUNT" = "1" ]; then
    TARGET="$PHONES"
  elif [ "$COUNT" = "0" ]; then
    bad "no phone connected — plug it in, enable Developer options → USB debugging, accept the prompt on the phone"
  else
    bad "several devices connected — pick one: HDC_TARGET=<serial> $0   ($(echo $PHONES))"
  fi
fi

if [ -n "$TARGET" ]; then
  ok "phone $TARGET"
  if [ "$MODE" = "udid" ]; then
    hdc -t "$TARGET" shell bm get --udid
    exit 0
  fi
  # 2. The app needs API 20 (HarmonyOS 6.0). HarmonyOS 4 / EMUI phones cannot install it.
  API="$(hdc -t "$TARGET" shell param get const.ohos.apiversion | tr -dc '0-9')"
  if [ -n "$API" ] && [ "$API" -ge "$MIN_API" ]; then
    ok "API $API (needs $MIN_API+)"
  else
    bad "phone reports API '${API:-unknown}', the app needs $MIN_API+ (HarmonyOS 6.0 or newer)"
  fi
fi

# 3. Signing. A real phone refuses an unsigned HAP.
if grep -q '"signingConfigs": \[\]' build-profile.json5; then
  bad "no signing config — DevEco → File → Project Structure → Signing Configs → Automatically generate signature (phone connected)"
else
  ok "signing config present"
fi

# 4. Backend. 127.0.0.1 on a phone is the phone itself, so a local dev backend is unreachable there.
if [ ! -f "$CONFIG" ]; then
  warn "no LocalConfig.ets yet — the build creates it empty, the app runs offline"
elif grep -qE "readonly BACKEND_URL: string = ''" "$CONFIG"; then
  warn "BACKEND_URL is empty — the app runs offline (drug check, emergency card and SOS still work)"
elif grep -qE "readonly BACKEND_URL: string = 'https?://(127\.0\.0\.1|localhost)" "$CONFIG"; then
  bad "BACKEND_URL points at this laptop (127.0.0.1) — set the deployed Supabase URL and its publishable key in $CONFIG"
else
  ok "backend configured"
fi

if [ "$problems" -gt 0 ]; then
  echo "$problems problem(s) — see docs/REAL_DEVICE.md" >&2
  exit 1
fi
if [ "$MODE" = "check" ]; then
  echo "Ready to install."
  exit 0
fi

set -e
rm -f "$HAP"   # never install a signed HAP left over from an earlier build
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
if [ ! -f "$HAP" ]; then
  echo "Build produced no signed HAP — check the signing config (docs/REAL_DEVICE.md)." >&2
  exit 1
fi

hdc -t "$TARGET" install -r "$HAP"
hdc -t "$TARGET" shell aa force-stop "$BUNDLE" || true
hdc -t "$TARGET" shell aa start -a EntryAbility -b "$BUNDLE"
sleep 2

mkdir -p "$(dirname "$SHOT")"
hdc -t "$TARGET" shell snapshot_display -f /data/local/tmp/celia.jpeg
hdc -t "$TARGET" file recv /data/local/tmp/celia.jpeg "$SHOT"
echo "Installed and launched. Screenshot: $SHOT"
