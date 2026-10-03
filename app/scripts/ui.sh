#!/usr/bin/env bash
# Drive the emulator/device from a terminal (used by Claude Code to test flows without clicking).
#   ui.sh shot [file]        screenshot (default app/build/screenshot.jpeg)
#   ui.sh list               text / inputs on screen with their pixel bounds
#   ui.sh tapt "text"        tap the last element whose text contains "text"
#   ui.sh tap X Y            tap pixel coordinates (from `list`)
#   ui.sh type X Y "text"    focus the field at X Y and type
#   ui.sh swipe X1 Y1 X2 Y2  swipe
#   ui.sh back               Back key (also closes the keyboard)
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$APP_DIR/env.sh"
mkdir -p "$APP_DIR/build"
LAYOUT="$APP_DIR/build/layout.json"

dump() {
  local f
  f=$(hdc shell uitest dumpLayout | grep -o '/data/[^ ]*json')
  hdc file recv "$f" "$LAYOUT" >/dev/null
}

case "${1:-}" in
  shot)
    out="${2:-$APP_DIR/build/screenshot.jpeg}"
    hdc shell snapshot_display -f /data/local/tmp/s.jpeg >/dev/null
    hdc file recv /data/local/tmp/s.jpeg "$out" >/dev/null
    echo "$out" ;;
  tap) hdc shell uitest uiInput click "$2" "$3" ;;
  type) hdc shell uitest uiInput inputText "$2" "$3" "$4" ;;
  swipe) hdc shell uitest uiInput swipe "$2" "$3" "$4" "$5" 600 ;;
  back) hdc shell uitest uiInput keyEvent Back ;;
  list|tapt)
    dump
    python3 - "$LAYOUT" "$1" "${2:-}" <<'PY'
import json, re, subprocess, sys
layout, mode, want = sys.argv[1], sys.argv[2], sys.argv[3].lower()
hits = []
def walk(n):
    a = n.get('attributes', {})
    text, kind = a.get('text', ''), a.get('type', '')
    m = re.findall(r'-?\d+', a.get('bounds', ''))
    if len(m) == 4 and (text or kind in ('TextInput', 'TextArea', 'SearchField', 'Button', 'Toggle')):
        x1, y1, x2, y2 = map(int, m)
        if mode == 'list':
            hint = a.get('hint', '')
            print(kind, repr(text[:60]), a.get('bounds'), f'hint={hint[:30]}' if hint else '')
        elif want in text.lower():
            hits.append((text, (x1 + x2) // 2, (y1 + y2) // 2))
    for c in n.get('children', []):
        walk(c)
walk(json.load(open(layout)))
if mode == 'tapt':
    if not hits:
        sys.exit(f'no element with text containing "{want}"')
    text, x, y = hits[-1]
    print(f'tap {text!r} at {x},{y}')
    subprocess.run(['hdc', 'shell', 'uitest', 'uiInput', 'click', str(x), str(y)], check=True)
PY
    ;;
  *) sed -n 2,10p "$0"; exit 1 ;;
esac
