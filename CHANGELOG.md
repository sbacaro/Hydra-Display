# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet.

## [0.1.0] - 2026-06-21

### Added
- Create and remove virtual (HiDPI/Retina) displays via the private
  `CGVirtualDisplay` CoreGraphics API, wrapped defensively with runtime
  availability checks.
- Resolution presets (16:9, 16:10, ultrawide, portrait) plus custom resolutions.
- Menu bar item with one-tap quick displays (4K Retina, 1440p, 1080p) and removal.
- Mirroring and desktop arrangement using the public `CGConfigureDisplay*` API.
- Native macOS Tahoe **Liquid Glass** interface with a shared design system.
- Apple-style app icon and `systemOrange` accent color.
- Custom **About** window and a Help menu linking to the project.
- Single `AppInfo` source of truth for the app's edition (name, version, links,
  legal strings) — consumed across the whole app.
- Ad-hoc "Sign to Run Locally" build configuration (no Developer ID required).
- Built with the **Swift 6** language mode (strict concurrency).

[Unreleased]: https://github.com/sbacaro/Hydra-Display/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sbacaro/Hydra-Display/releases/tag/v0.1.0
