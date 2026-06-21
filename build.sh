#!/usr/bin/env bash
#
# build.sh — build a Release "Hydra Display.app" without a Developer ID.
# Output: ./build/Build/Products/Release/Hydra Display.app
#
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Building Hydra Display (Release, ad-hoc signed)…"
xcodebuild \
  -project HydraDisplay.xcodeproj \
  -scheme HydraDisplay \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  build

APP="build/Build/Products/Release/Hydra Display.app"
echo ""
echo "==> Done."
echo "    App: $APP"
echo ""
echo "To run:        open \"$APP\""
echo "To distribute: zip it and attach to a GitHub Release. Tell users to"
echo "               right-click → Open, or run:"
echo "               xattr -dr com.apple.quarantine '/Applications/Hydra Display.app'"
