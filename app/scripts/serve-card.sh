#!/usr/bin/env bash
# Serve the emergency-card viewer (site/) from this laptop so a phone on the same Wi-Fi can open the card QR.
# Points the app's QR at http://<laptop-ip>:<port>/card/ (gitignored LocalConfig.ets), rebuilds + installs the
# app, then serves until Ctrl+C. Undo: set CARD_VIEWER_URL back to '' in LocalConfig.ets and rebuild.
# Usage:  app/scripts/serve-card.sh [port]
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$APP_DIR/.." && pwd)"
PORT="${1:-8080}"
CONFIG="$APP_DIR/entry/src/main/ets/common/LocalConfig.ets"

IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
if [ -z "$IP" ]; then
  echo "No LAN IP found - connect to Wi-Fi first." >&2
  exit 1
fi
URL="http://$IP:$PORT/card/"

[ -f "$CONFIG" ] || cp "$APP_DIR/entry/src/main/ets/common/LocalConfig.example.ets" "$CONFIG"
if grep -q "CARD_VIEWER_URL" "$CONFIG"; then
  sed -i '' -E "s#(CARD_VIEWER_URL: string = )'[^']*'#\1'$URL'#" "$CONFIG"
else
  sed -i '' -E "s#^}\$#  static readonly CARD_VIEWER_URL: string = '$URL';\n}#" "$CONFIG"
fi
echo "Card viewer → $URL"

python3 "$ROOT/data/export_card_site.py"
"$APP_DIR/scripts/run.sh"

echo
echo "Serving $ROOT/site at $URL  (phone must be on the same Wi-Fi; Ctrl+C to stop)"
cd "$ROOT/site"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
