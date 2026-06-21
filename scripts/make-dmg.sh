#!/usr/bin/env bash
#
# make-dmg.sh — build a custom, branded .dmg from a built .app.
#
# Usage:  scripts/make-dmg.sh "<path/to/Hydra Display.app>" <output.dmg>
#
# Requires `create-dmg` (https://github.com/create-dmg/create-dmg):
#     brew install create-dmg
#
set -euo pipefail

APP="${1:?Usage: make-dmg.sh <App.app> <output.dmg>}"
OUT="${2:?Usage: make-dmg.sh <App.app> <output.dmg>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BG="$SCRIPT_DIR/dmg/dmg-background.png"
VOLNAME="Hydra Display"
APP_BASENAME="$(basename "$APP")"

if [[ ! -d "$APP" ]]; then
  echo "error: app not found at '$APP'" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: 'create-dmg' is required. Install it with:" >&2
  echo "    brew install create-dmg" >&2
  exit 1
fi

rm -f "$OUT"
mkdir -p "$(dirname "$OUT")"

echo "==> Building DMG: $OUT"
create-dmg \
  --volname "$VOLNAME" \
  --background "$BG" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "$APP_BASENAME" 160 185 \
  --app-drop-link 500 185 \
  --hide-extension "$APP_BASENAME" \
  --no-internet-enable \
  "$OUT" \
  "$APP"

echo "==> DMG ready: $OUT"
