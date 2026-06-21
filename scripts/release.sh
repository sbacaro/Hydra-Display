#!/usr/bin/env bash
#
# release.sh — one-command release for Hydra Display.
#
# It will, in order:
#   1. Build a Release HydraDisplay.app (ad-hoc signed, no Developer ID)
#   2. Package a branded .dmg and a .zip, with SHA-256 checksums
#   3. Commit & push the current branch
#   4. Create and push the git tag (vX.Y.Z)
#   5. Create the GitHub release, attach the release notes, and upload the assets
#
# Requirements (all on macOS):
#   - Xcode 26+            (xcodebuild)
#   - create-dmg           (brew install create-dmg)
#   - GitHub CLI, signed in (brew install gh && gh auth login)
#
# Usage:
#   scripts/release.sh                 # full release
#   scripts/release.sh --dry-run       # build + package only (no git/GitHub)
#   scripts/release.sh --skip-release  # build, package, push, tag (no GitHub release)
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
REPO_SLUG="sbacaro/Hydra-Display"
PROJECT="HydraDisplay.xcodeproj"
SCHEME="HydraDisplay"
APP_NAME="HydraDisplay"
CONFIG="Release"
BRANCH="main"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
DERIVED="$BUILD_DIR/DerivedData"
DIST="$ROOT/dist"

DRY_RUN=false
SKIP_RELEASE=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-release) SKIP_RELEASE=true ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf "\n\033[1;33m==> %s\033[0m\n" "$1"; }
die() { printf "\033[1;31merror:\033[0m %s\n" "$1" >&2; exit 1; }

# ----------------------------------------------------------------------------
# 0. Pre-flight
# ----------------------------------------------------------------------------
say "Checking tools"
command -v xcodebuild >/dev/null || die "xcodebuild not found (install Xcode 26+)."
command -v create-dmg >/dev/null || die "create-dmg not found — run: brew install create-dmg"
if ! $DRY_RUN; then
  command -v gh >/dev/null || die "GitHub CLI not found — run: brew install gh"
  gh auth status >/dev/null 2>&1 || die "Not signed in to GitHub — run: gh auth login"
fi
xcodebuild -version

# ----------------------------------------------------------------------------
# 1. Resolve version -> tag and release notes
# ----------------------------------------------------------------------------
say "Reading version from the project"
VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')"
[[ -n "${VERSION:-}" ]] || die "Could not read MARKETING_VERSION."
TAG="v$VERSION"
NOTES="docs/releases/$TAG.md"
echo "Version: $VERSION   Tag: $TAG"
[[ -f "$NOTES" ]] || die "Release notes not found at $NOTES"

# ----------------------------------------------------------------------------
# 2. Build
# ----------------------------------------------------------------------------
say "Building $APP_NAME ($CONFIG, ad-hoc signed)"
rm -rf "$DERIVED"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  clean build

APP_PATH="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || die "Build succeeded but app not found at $APP_PATH"

# ----------------------------------------------------------------------------
# 3. Package: .dmg + .zip + checksums
# ----------------------------------------------------------------------------
say "Packaging artifacts"
rm -rf "$DIST"; mkdir -p "$DIST"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ZIP="$DIST/$APP_NAME-$VERSION.app.zip"

"$ROOT/scripts/make-dmg.sh" "$APP_PATH" "$DMG"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP"

( cd "$DIST" && shasum -a 256 *.dmg *.zip > SHA256SUMS.txt )
echo "Artifacts:"; ls -lh "$DIST"

if $DRY_RUN; then
  say "Dry run complete — artifacts are in ./dist (no git/GitHub changes made)."
  exit 0
fi

# ----------------------------------------------------------------------------
# 4. Commit & push
# ----------------------------------------------------------------------------
say "Pushing $BRANCH"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repository."
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "release: $TAG"
fi
git push origin "$BRANCH"

# ----------------------------------------------------------------------------
# 5. Tag
# ----------------------------------------------------------------------------
say "Tagging $TAG"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally — reusing it."
else
  git tag -a "$TAG" -m "Hydra Display $TAG"
fi
git push origin "$TAG"

if $SKIP_RELEASE; then
  say "Stopped before creating the GitHub release (--skip-release)."
  exit 0
fi

# ----------------------------------------------------------------------------
# 6. GitHub release + upload
# ----------------------------------------------------------------------------
say "Creating GitHub release $TAG"
if gh release view "$TAG" --repo "$REPO_SLUG" >/dev/null 2>&1; then
  echo "Release exists — uploading/overwriting assets."
  gh release upload "$TAG" "$DMG" "$ZIP" "$DIST/SHA256SUMS.txt" \
    --repo "$REPO_SLUG" --clobber
else
  gh release create "$TAG" "$DMG" "$ZIP" "$DIST/SHA256SUMS.txt" \
    --repo "$REPO_SLUG" \
    --title "Hydra Display $TAG" \
    --notes-file "$NOTES"
fi

say "Done! Release published:"
echo "https://github.com/$REPO_SLUG/releases/tag/$TAG"
