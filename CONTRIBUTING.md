# Contributing to Hydra Display

Thanks for your interest in improving Hydra Display! Contributions of all kinds are
welcome: bug reports, feature ideas, documentation, and code.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating,
you agree to uphold it.

## License of contributions

Hydra Display is licensed under the **GNU General Public License v3.0 or later**
(`GPL-3.0-or-later`). By submitting a contribution, you agree that your work is
licensed under the same terms. Please keep the SPDX header at the top of every source
file:

```swift
// SPDX-License-Identifier: GPL-3.0-or-later
```

## Getting started

1. **Requirements:** macOS 26 (Tahoe) and Xcode 26 or later.
2. Fork and clone the repository.
3. Open `HydraDisplay.xcodeproj` and build with ⌘R, or run `./build.sh`.
4. The project builds with ad-hoc signing — no Apple Developer account is needed.

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) to understand how the app is laid
out, and [docs/PRIVATE_API.md](docs/PRIVATE_API.md) before touching the
`Bridge/` layer.

## Branch & commit conventions

- Create a topic branch: `feature/<short-name>` or `fix/<short-name>`.
- Write clear, present-tense commit messages. [Conventional Commits](https://www.conventionalcommits.org/)
  are encouraged but not required, e.g. `feat: add per-display refresh-rate picker`.
- Keep pull requests focused; one logical change per PR is easier to review.

## Coding style

- Swift, SwiftUI-first. Follow the existing structure:
  - `App/` — entry point and scenes
  - `Views/` — SwiftUI screens and components
  - `Models/` — state and CoreGraphics orchestration
  - `Bridge/` — the private-API boundary (be extra careful here)
  - `DesignSystem/` — shared tokens and reusable UI pieces
- **Liquid Glass discipline:** content lives on the material layer; reserve
  `glassEffect`/glass button styles for the floating control layer, and never stack
  glass on glass. Reuse `SectionCard`, `InfoRow`, `Badge`, and the `surfaceCard`
  modifier instead of inventing new card styles.
- A `.swiftlint.yml` is included. If you have SwiftLint installed, run `swiftlint`
  before committing. CI does not block on lint, but a clean run is appreciated.

## Running the tests

The project ships a full test suite. In Xcode press **⌘U**, or from the command line:

```bash
# Everything (unit + UI)
xcodebuild -project HydraDisplay.xcodeproj -scheme HydraDisplay \
  -destination 'platform=macOS' test

# Unit tests only (fast, no UI automation)
xcodebuild -project HydraDisplay.xcodeproj -scheme HydraDisplay \
  -destination 'platform=macOS' -only-testing:HydraDisplayTests test
```

- **`HydraDisplayTests`** — Swift Testing unit tests for the models and logic
  (resolution presets, the virtual-display model, persistence, the updater's version
  comparison and JSON parsing, `AppInfo`, settings, and the display manager).
- **`HydraDisplayUITests`** — XCUITest smoke tests for launch and navigation.

CI runs the unit tests automatically once a macOS 26 runner is available.

## Submitting a pull request

1. Make sure the app builds and runs.
2. Update `CHANGELOG.md` under the **Unreleased** section.
3. Update documentation if behavior changed.
4. Open the PR using the template and describe what and why.

## Reporting bugs & requesting features

Use the [issue templates](https://github.com/sbacaro/Hydra-Display/issues/new/choose).
For anything security- or private-API-related, see [SECURITY.md](SECURITY.md).

Thank you for helping make Hydra Display better!
