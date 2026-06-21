# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-06-21

### Added
- **Live resolution switching:** change any display's active resolution (physical or
  virtual) from a menu on its Overview card and in the display detail pane, via the
  public CoreGraphics mode API.
- **App Intents / Shortcuts:** "Create Virtual Display" (with a resolution choice) and
  "Remove All Virtual Displays" are available in the Shortcuts app and Spotlight; both
  run against the shared display manager.
- **First-run onboarding:** a welcome screen explaining the app and the private-API /
  Gatekeeper caveat.
- **Named profiles:** save the current set of virtual displays as a named profile and
  re-apply it later from a new **Profiles** sidebar section.
- **Real-time Picture in Picture:** open any display *or* a specific app window (e.g. a
  video player) in a floating, always-on-top window that streams live via
  ScreenCaptureKit — it stays visible even over full-screen apps. Pick a source from the
  new **Picture in Picture** sidebar section, right-click a display card, or use the
  detail-pane button.
- **Global keyboard shortcuts** (opt-in, in Settings): ⌃⌥⌘N creates a 4K Retina display,
  ⌃⌥⌘R removes all.
- **Localization:** Brazilian Portuguese (pt-BR) for the core UI, via a String Catalog
  (English remains the source language).
- **Persistence:** created virtual displays are saved and automatically recreated
  on the next launch (toggle in Settings).
- **Open at Login:** optional launch-at-login via ServiceManagement.
- **Settings window** (⌘,) with the above options, plus a Settings shortcut in the
  menu bar.
- **In-app auto-update** (no Sparkle): checks GitHub Releases, downloads the new
  build, and installs it over the running app. The privileged swap runs through the
  native macOS authentication dialog — no visible terminal. Includes a "Check for
  Updates…" menu item, an Updates tab in Settings, and status in the About window.
- **Update-available indicators** in the sidebar and the menu bar.
- **Test suite:** `HydraDisplayTests` (Swift Testing unit tests across presets, the
  virtual-display model, persistence, the updater, app info, settings, and the display
  manager) and `HydraDisplayUITests` (launch/navigation smoke tests), runnable with ⌘U.

### Fixed
- The app now presents a consistent **"Hydra Display"** name in the menu bar, Dock, and
  Finder (via an explicit `Info.plist`), instead of the build target's "HydraDisplay".

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

[Unreleased]: https://github.com/sbacaro/Hydra-Display/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/sbacaro/Hydra-Display/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sbacaro/Hydra-Display/releases/tag/v0.1.0
