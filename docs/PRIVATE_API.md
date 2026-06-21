# The private virtual-display API

Hydra Display's core feature — creating virtual displays — depends on **private,
undocumented Apple APIs**. This document explains what they are, why we use them, and
the trade-offs that follow. Read it before working in `Bridge/`.

## Why a private API at all?

macOS exposes **no public API** for creating virtual displays. The only mechanism is a
family of private CoreGraphics classes that Apple uses internally (for Sidecar, screen
sharing, and similar features):

- `CGVirtualDisplayDescriptor` — the immutable identity of a display before creation
  (name, vendor/product IDs, physical size, color primaries).
- `CGVirtualDisplay` — the live display, created from a descriptor.
- `CGVirtualDisplaySettings` — mutable settings (modes + HiDPI flag) applied to a live
  display.
- `CGVirtualDisplayMode` — a single advertised resolution + refresh rate.

Every comparable tool (BetterDisplay, FreeDisplay, SimpleDisplay, and others) uses the
same classes — there is simply no alternative on macOS today.

## How we use them safely

The private surface is confined to two files:

- [`Bridge/CGVirtualDisplayPrivate.h`](../HydraDisplay/Bridge/CGVirtualDisplayPrivate.h)
  declares the ObjC interfaces. The shapes are derived from the public class-dumps at
  [w0lfschild/macOS_headers](https://github.com/w0lfschild/macOS_headers).
- [`Bridge/VirtualDisplayBridge.swift`](../HydraDisplay/Bridge/VirtualDisplayBridge.swift)
  wraps them and is the **only** Swift file allowed to reference the private classes.

Defensive measures:

1. **Runtime availability check.** `VirtualDisplayBridge.isAvailable` uses
   `NSClassFromString` to confirm all four classes exist before any are touched. If a
   future macOS removes them, the app disables the feature and shows a banner instead of
   crashing.
2. **Throwing, not crashing.** `create(_:)` throws `VirtualDisplayError` for every
   failure path (missing API, rejected settings, invalid display ID). The UI surfaces
   these as alerts.
3. **Encapsulation.** The live `CGVirtualDisplay` is stored as `AnyObject` inside
   `VirtualDisplayHandle`, so nothing outside the bridge can call private methods on it.

## Consequences (please read before contributing)

Using a private API is a deliberate trade-off:

| Consequence | Detail |
| ----------- | ------ |
| ❌ **No Mac App Store** | Apps that link private symbols are rejected. Distribution is via GitHub Releases only. |
| ⚠️ **May break on future macOS** | These classes have been broadly source-compatible for ~a decade, but Apple can change or remove them at any time, in any release. |
| 🔓 **No App Sandbox** | The API is unavailable inside the sandbox, so the app ships unsandboxed (`com.apple.security.app-sandbox = false`). |
| 🔏 **No notarization** | Without a Developer ID the app isn't notarized; users clear Gatekeeper quarantine manually. |

Mirroring and arrangement use the **public** `CGConfigureDisplay*` API and are not
subject to these caveats.

## If the API changes

If a macOS update breaks creation:

1. `isAvailable` will likely return `false` (class renamed/removed) — the app already
   degrades gracefully.
2. If the classes exist but their method signatures changed, `create(_:)` will throw.
3. To fix: re-dump the current CoreGraphics headers (e.g. via
   [w0lfschild/macOS_headers](https://github.com/w0lfschild/macOS_headers) or a local
   class-dump), update `CGVirtualDisplayPrivate.h`, and adjust the wrapper. Keep all
   changes inside `Bridge/`.

## Legal note

These APIs are not part of any public SDK contract, and this project is not affiliated
with or endorsed by Apple Inc. See the [LICENSE](../LICENSE) for the additional note on
private-API usage.
