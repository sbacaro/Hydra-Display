#!/usr/bin/env bash
#
# release.sh — release helper for Hydra Display.
#
# Run it with no arguments and it asks what you want to do:
#
#   • Push only     — commit & push the current branch
#   • Full release  — build, package (.dmg + .app.zip + checksums), push, tag,
#                     and publish the GitHub release
#
# Or skip the prompt with a flag:
#
#   scripts/release.sh --push-only     # commit & push only
#   scripts/release.sh --full          # the whole release
#   scripts/release.sh --dry-run       # build + package only (no git/GitHub)
#   scripts/release.sh --skip-release  # build, package, push, tag (no GitHub release)
#   scripts/release.sh --build-only    # just compile (quick sanity check)
#
# Requirements (full release, all on macOS):
#   - Xcode 26+   (xcodebuild)
#   - create-dmg  (brew install create-dmg)
#   - gh, signed in (brew install gh && gh auth login)
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
REPO_SLUG="sbacaro/Hydra-Display"
PROJECT="HydraDisplay.xcodeproj"
SCHEME="HydraDisplay"
APP_NAME="HydraDisplay"            # prefix for download artifacts (no spaces, clean URLs)
APP_BUNDLE="Hydra Display"         # the .app bundle name on disk (PRODUCT_NAME)
CONFIG="Release"
BRANCH="main"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BUILD_DIR="$ROOT/build"; DERIVED="$BUILD_DIR/DerivedData"; DIST="$ROOT/dist"

# ----------------------------------------------------------------------------
# Pretty output
# ----------------------------------------------------------------------------
if [[ -t 1 ]]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
  RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'
else
  B=; D=; R=; RED=; GRN=; YLW=; CYN=
fi

title() { printf "\n${B}${CYN}❯ %s${R}\n" "$1"; }
info()  { printf "  ${D}%s${R}\n" "$1"; }
ok()    { printf "  ${GRN}✓${R} %s\n" "$1"; }
warn()  { printf "  ${YLW}!${R} %s\n" "$1"; }
die()   { printf "\n${RED}✗ %s${R}\n" "$1" >&2; exit 1; }

# run_step "Label" cmd args… — runs quietly with a spinner; only shows output on failure.
run_step() {
  local label="$1"; shift
  local log; log="$(mktemp)"
  ( "$@" ) >"$log" 2>&1 &
  local pid=$! spin='|/-\' i=0
  if [[ -t 1 ]]; then
    while kill -0 "$pid" 2>/dev/null; do
      i=$(( (i + 1) % 4 ))
      printf "\r  ${CYN}%s${R} %s" "${spin:$i:1}" "$label"
      sleep 0.1
    done
  fi
  if wait "$pid"; then
    printf "\r  ${GRN}✓${R} %s\033[K\n" "$label"; rm -f "$log"
  else
    printf "\r  ${RED}✗${R} %s\033[K\n" "$label"
    printf "\n${RED}Failed — last 40 lines of output:${R}\n"; tail -n 40 "$log"; rm -f "$log"
    exit 1
  fi
}

# ----------------------------------------------------------------------------
# Mode selection
# ----------------------------------------------------------------------------
MODE=""; DRY_RUN=false; SKIP_RELEASE=false; BUILD_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --push-only)    MODE="push" ;;
    --full)         MODE="full" ;;
    --dry-run)      MODE="full"; DRY_RUN=true ;;
    --skip-release) MODE="full"; SKIP_RELEASE=true ;;
    --build-only)   MODE="full"; BUILD_ONLY=true; DRY_RUN=true ;;
    -h|--help)      sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

choose_mode() {
  printf "\n${B}${CYN}  Hydra Display · Release${R}\n\n"
  printf "    ${B}1${R}  Push only      ${D}commit & push the current branch${R}\n"
  printf "    ${B}2${R}  Full release   ${D}build, package, tag & publish to GitHub${R}\n"
  printf "    ${B}q${R}  Cancel\n\n"
  local choice; read -rp "  ${B}Choose${R} [1/2/q]: " choice
  case "$choice" in
    1) MODE="push" ;;
    2) MODE="full" ;;
    ""|q|Q) info "Cancelled."; exit 0 ;;
    *) die "Invalid choice: $choice" ;;
  esac
}

if [[ -z "$MODE" ]]; then
  if [[ -t 0 ]]; then choose_mode
  else die "No mode given and not a TTY — pass --push-only or --full."; fi
fi

# ----------------------------------------------------------------------------
# Push only
# ----------------------------------------------------------------------------
do_push() {
  title "Push"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repository."
  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ -n "$(git status --porcelain)" ]]; then
    local msg; read -rp "  ${B}Commit message${R} [chore: update]: " msg
    msg="${msg:-chore: update}"
    git add -A
    run_step "Committing changes" git commit -m "$msg"
  else
    info "Working tree clean — nothing to commit."
  fi
  run_step "Pushing $branch" git push origin "$branch"
  ok "Pushed ${B}$branch${R}."
}

# ----------------------------------------------------------------------------
# Full release
# ----------------------------------------------------------------------------
do_full() {
  title "Pre-flight"
  command -v xcodebuild >/dev/null || die "xcodebuild not found (install Xcode 26+)."
  $BUILD_ONLY || command -v create-dmg >/dev/null || die "create-dmg not found — brew install create-dmg"
  if ! $DRY_RUN; then
    command -v gh >/dev/null || die "GitHub CLI not found — brew install gh"
    gh auth status >/dev/null 2>&1 || die "Not signed in to GitHub — run: gh auth login"
  fi
  ok "Tools ready."

  title "Version"
  local version
  version="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -showBuildSettings 2>/dev/null | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')"
  [[ -n "${version:-}" ]] || die "Could not read MARKETING_VERSION."
  local tag="v$version" notes="docs/releases/v$version.md"
  info "Version $version  ·  tag $tag"
  $BUILD_ONLY || [[ -f "$notes" ]] || die "Release notes not found at $notes"

  title "Build"
  run_step "Compiling $APP_BUNDLE.app ($CONFIG, ad-hoc signed)" \
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
      -derivedDataPath "$DERIVED" \
      CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
      DEVELOPMENT_TEAM="" clean build
  local app_path="$DERIVED/Build/Products/$CONFIG/$APP_BUNDLE.app"
  [[ -d "$app_path" ]] || die "Build succeeded but app not found at $app_path"
  ok "Built $APP_BUNDLE.app"

  if $BUILD_ONLY; then info "Build-only — done."; return; fi

  title "Package"
  rm -rf "$DIST"; mkdir -p "$DIST"
  local dmg="$DIST/$APP_NAME-$version.dmg" zip="$DIST/$APP_NAME-$version.app.zip"
  run_step "Building .dmg" "$ROOT/scripts/make-dmg.sh" "$app_path" "$dmg"
  run_step "Zipping .app"  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip"
  run_step "Checksums"     bash -c "cd '$DIST' && shasum -a 256 *.dmg *.zip > SHA256SUMS.txt"
  info "Artifacts in ./dist:  $(cd "$DIST" && ls *.dmg *.zip SHA256SUMS.txt | tr '\n' ' ')"

  if $DRY_RUN; then ok "Dry run complete — no git/GitHub changes made."; return; fi

  title "Publish"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repository."
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    run_step "Committing release" git commit -m "release: $tag"
  fi
  run_step "Pushing $BRANCH" git push origin "$BRANCH"

  if git rev-parse "$tag" >/dev/null 2>&1; then info "Tag $tag already exists — reusing it."
  else run_step "Tagging $tag" git tag -a "$tag" -m "Hydra Display $tag"; fi
  run_step "Pushing tag $tag" git push origin "$tag"

  if $SKIP_RELEASE; then ok "Stopped before the GitHub release (--skip-release)."; return; fi

  if gh release view "$tag" --repo "$REPO_SLUG" >/dev/null 2>&1; then
    run_step "Updating GitHub release $tag" \
      gh release upload "$tag" "$dmg" "$zip" "$DIST/SHA256SUMS.txt" --repo "$REPO_SLUG" --clobber
  else
    run_step "Creating GitHub release $tag" \
      gh release create "$tag" "$dmg" "$zip" "$DIST/SHA256SUMS.txt" \
        --repo "$REPO_SLUG" --title "Hydra Display $tag" --notes-file "$notes"
  fi
  ok "Published: ${B}https://github.com/$REPO_SLUG/releases/tag/$tag${R}"
}

case "$MODE" in
  push) do_push ;;
  full) do_full ;;
esac

printf "\n${GRN}${B}Done.${R}\n"
