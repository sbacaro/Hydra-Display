# Releasing Hydra Display

Releases are produced with a single script, [`scripts/release.sh`](../scripts/release.sh).
Because the app uses a private API and is ad-hoc signed, releases are distributed only
via GitHub Releases (not the Mac App Store).

## Prerequisites (one-time)

On the Mac that will cut the release:

```bash
# Xcode 26+ must be installed (provides xcodebuild).
brew install create-dmg     # custom .dmg layout
brew install gh             # GitHub CLI
gh auth login               # sign in to GitHub (needs repo write access)
```

## Cut a release

1. **Bump the version** in Xcode → target **HydraDisplay** → *General* →
   *Identity*: set **Version** (`MARKETING_VERSION`, e.g. `0.2.0`) and, if you like,
   the **Build** (`CURRENT_PROJECT_VERSION`). `AppInfo` and the About window read these
   automatically — there is nothing else to edit.
2. **Write the release notes** at `docs/releases/vX.Y.Z.md` (copy the previous file as a
   template) and update `CHANGELOG.md`.
3. **Run the release script** from the repo root:

   ```bash
   ./scripts/release.sh
   ```

That's it. The script will:

| Step | What it does |
| ---- | ------------ |
| Build | `xcodebuild` Release, ad-hoc signed (`CODE_SIGN_IDENTITY="-"`, no team) |
| Package | Branded **`.dmg`** (via `create-dmg`) + **`.app.zip`** (via `ditto`) into `dist/` |
| Checksums | `SHA256SUMS.txt` for every artifact |
| Push | Commits pending changes and pushes `main` |
| Tag | Creates and pushes `vX.Y.Z` |
| Release | `gh release create` with the notes file, uploading the `.dmg`, `.zip`, and checksums |

The final output prints the release URL.

## Useful flags

```bash
./scripts/release.sh --build-only     # just compile the app (no create-dmg / gh needed) — quickest sanity check
./scripts/release.sh --dry-run        # build + package the .dmg/.zip; no git/GitHub changes (needs create-dmg)
./scripts/release.sh --skip-release   # build, package, push, and tag — but don't create the GitHub release
```

## Just the DMG

To (re)build only the disk image from an existing `.app`:

```bash
scripts/make-dmg.sh /path/to/HydraDisplay.app dist/HydraDisplay.dmg
```

The DMG window layout and the background image live in
[`scripts/dmg/`](../scripts/dmg/).

## Notes for downloaders

The app is **not notarized**. On first launch users must right-click → **Open** (or run
`xattr -dr com.apple.quarantine /Applications/HydraDisplay.app`). This is documented in
the README and in every release's notes.
