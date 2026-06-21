# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2026-06-21

### Fixed
- The PIP source picker now also lists windows on other Spaces (e.g. a full-screen Safari
  video) and windows with no title, and hides background helper/agent apps.
- PIP capture resolution is now capped (longest side ≤ 2560 px), preventing a system-wide
  stall when picking a very large window such as a full-screen Retina video.
- A captured window that enters or leaves **full screen** (which gives it a new window ID)
  is now re-bound automatically, instead of going black.
- PIP frames are **coalesced** — only the most recent frame is drawn — so a burst of
  frames can no longer pile up on the main thread under load.

## [0.3.0] - 2026-06-21

### Added
- **Unified logging & diagnostics export:** key events (display create/configure,
  update checks and verification, capture errors) now go through `os.Logger`. A new
  **Diagnostics** section in Settings exports a plain-text report — app/system info, the
  current display topology with color adjustments, open PIP windows, and recent log
  entries — to a location you choose, for attaching to bug reports.
- **Picture-in-Picture controls:** each floating PIP window now has a hover-revealed
  strip to set its **opacity** and turn on **click-through** (the pointer passes through
  to whatever's behind). Multiple PIP windows can be open at once; a new **Picture in
  Picture** section in the menu bar lists them all and is the reliable way to toggle
  click-through back off or close a window.
- **Software dimming & color temperature:** per-display brightness and a warm↔cool
  white-point, applied through the public CoreGraphics gamma API — no DDC or extra
  hardware, and it works on physical *and* virtual displays. Controls live on each
  Overview card (sun button) and in the virtual-display detail pane; settings persist
  per display and re-apply after sleep/wake, and quitting the app restores normal color.

### Security
- **Verified auto-updates:** before installing, the updater downloads the release's
  published `SHA256SUMS.txt`, recomputes the SHA-256 of the downloaded `.app.zip`, and
  refuses to install if the hash is missing or doesn't match — closing a tampering /
  corruption vector on the privileged self-replace.

### Changed
- The application bundle is now named **`Hydra Display.app`** (the menu bar, Dock, and
  Finder all show "Hydra Display"); download artifacts keep the `HydraDisplay-x.y.z`
  prefix.
- The Picture-in-Picture feed no longer draws the mouse pointer.
- Removed the large "New Virtual Display" card from the Overview — use the **+** button in
  the toolbar (or the menu bar) instead.

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

[Unreleased]: https://github.com/sbacaro/Hydra-Display/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/sbacaro/Hydra-Display/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/sbacaro/Hydra-Display/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/sbacaro/Hydra-Display/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sbacaro/Hydra-Display/releases/tag/v0.1.0
