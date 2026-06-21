# Architecture

This document explains how Hydra Display is structured and how data flows through it.
It is aimed at contributors who want to extend the app.

## High-level overview

Hydra Display is a small, single-target SwiftUI app for macOS 26 (Tahoe). It has three
conceptual layers:

```
┌─────────────────────────────────────────────────────────┐
│  Views (SwiftUI)            App/, Views/, DesignSystem/   │  Presentation
│   Overview · Create · Detail · Arrangement · MenuBar      │
├─────────────────────────────────────────────────────────┤
│  DisplayManager (@Observable, @MainActor)   Models/       │  State & orchestration
│   owns virtual displays · enumerates screens · mirroring  │
├─────────────────────────────────────────────────────────┤
│  VirtualDisplayBridge + CGVirtualDisplayPrivate   Bridge/ │  Private-API boundary
│   the ONLY place that touches private CoreGraphics        │
└─────────────────────────────────────────────────────────┘
```

The golden rule: **only `Bridge/` knows about the private API.** Everything above it
works with plain Swift value types (`VirtualDisplaySpec`, `VirtualDisplayMode`,
`DisplayInfo`) and never imports the private classes directly.

## Source layout

| Folder | Responsibility |
| ------ | -------------- |
| `App/` | `@main` entry point. Declares the main `Window` and the `MenuBarExtra`, and injects the shared `DisplayManager` into the environment. |
| `Views/` | All SwiftUI screens and components: `ContentView` (the split-view shell), `OverviewView`, `CreateDisplaySheet`, `DisplayDetailView`, `ArrangementView`, `MenuBarView`. |
| `Models/` | `DisplayManager` (state + CoreGraphics orchestration) and `ResolutionPresets` (the curated resolution catalogue). |
| `Bridge/` | `CGVirtualDisplayPrivate.h` (reverse-engineered ObjC interfaces) and `VirtualDisplayBridge.swift` (a defensive Swift wrapper). |
| `DesignSystem/` | Tokens (`Theme`) and reusable UI: `SectionCard`, `InfoRow`, `Badge`, and the `surfaceCard` modifier. |
| `Resources/` | `Assets.xcassets` — the app icon and the `systemOrange` accent color. |

## State management

`DisplayManager` is the single source of truth. It is an `@Observable`, `@MainActor`
class created once in `HydraDisplayApp` and shared with every scene via
`.environment(...)`. Views read it with `@Environment(DisplayManager.self)`.

It exposes:

- `virtualHandles: [VirtualDisplayHandle]` — the live virtual displays Hydra created
  this session. Each handle holds a strong reference to the underlying private object;
  dropping the handle tears the display down (see lifecycle below).
- `allDisplays: [DisplayInfo]` — a UI-friendly snapshot of **every** screen attached to
  the Mac (built-in, external, and virtual), rebuilt from CoreGraphics on demand.
- `lastError: String?` — surfaced to the UI as an alert.
- `isVirtualDisplaySupported: Bool` — whether the private API is present on this OS.

The manager observes `NSApplication.didChangeScreenParametersNotification` and
re-enumerates whenever the display topology changes.

## Virtual-display lifecycle

Creation flows top-down and destruction is reference-counted:

1. A view builds a `VirtualDisplaySpec` (name, HiDPI, modes) and calls
   `DisplayManager.createVirtualDisplay(_:)`.
2. The manager calls `VirtualDisplayBridge.create(_:)`, which constructs a
   `CGVirtualDisplayDescriptor`, applies `CGVirtualDisplaySettings`, and returns a
   `VirtualDisplayHandle` wrapping the live `CGVirtualDisplay`.
3. The handle is stored in `virtualHandles`. macOS now sees a new monitor.
4. To remove a display, the manager drops the handle from `virtualHandles`. Because the
   handle held the only strong reference to the private object, ARC releases it and the
   display disappears.

> This "ownership = existence" model is why handles are kept in an array on the manager
> rather than created and forgotten.

## Mirroring & arrangement (public API)

Unlike creation, mirroring and arrangement use the **public** CoreGraphics
display-configuration API and therefore work for real *and* virtual displays:

- `CGBeginDisplayConfiguration` / `CGCompleteDisplayConfiguration` wrap each change in a
  transaction (`DisplayManager.withConfiguration`).
- `CGConfigureDisplayMirrorOfDisplay` mirrors one display onto another (or
  `kCGNullDirectDisplay` to stop).
- `CGConfigureDisplayOrigin` repositions a display in the global desktop space; the
  `ArrangementView` canvas maps drag gestures to new origins.

## UI / design system

The app follows Apple's macOS Tahoe **Liquid Glass** guidance:

- **Content** (cards, rows, sections) lives on the *material* layer via `surfaceCard`
  and `SectionCard`.
- **Liquid Glass** is reserved for the floating control layer. In practice the system
  chrome (sidebar, toolbar, sheets, the menu-bar panel) adopts glass automatically, and
  the app adds at most one explicit `glassEffect` (the "unsupported" banner).
- Glass is never stacked on glass.

`Theme` centralizes spacing and corner radii (continuous/concentric) so every screen
shares the same rhythm.

## Threading

All UI state lives on the main actor (`DisplayManager` is `@MainActor`). The private
descriptor uses a background dispatch queue internally, but the bridge marshals results
back before the manager touches them. CoreGraphics registration is asynchronous, so the
manager re-enumerates shortly after create/remove with a short delay.

## Extending the app

- **New screen:** add a `View` to `Views/`, a case to `SidebarItem`, and a branch in
  `ContentView.detail`.
- **New resolution group:** edit `ResolutionPresets.groups`.
- **New display capability:** prefer the public CoreGraphics API in `DisplayManager`. If
  you must reach for more private API, keep it isolated in `Bridge/` and guard it with a
  runtime availability check. See [PRIVATE_API.md](PRIVATE_API.md).
