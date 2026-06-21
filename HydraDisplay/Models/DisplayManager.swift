//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  DisplayManager.swift
//  Hydra Display
//
//  Single source of truth for the app: owns the live virtual displays,
//  enumerates every connected screen, and drives mirroring + arrangement
//  through the *public* CoreGraphics display-configuration API.
//

import Foundation
import CoreGraphics
import AppKit
import Observation

/// Lightweight, UI-facing snapshot of any screen attached to the Mac
/// (built-in, external, or one of ours).
struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    var name: String
    var pixelWidth: Int
    var pixelHeight: Int
    var isVirtualHydra: Bool
    var isMirrored: Bool
    var mirrorSourceID: CGDirectDisplayID?
    var origin: CGPoint
    var isMain: Bool

    var resolutionLabel: String { "\(pixelWidth) × \(pixelHeight)" }
}

@Observable
@MainActor
final class DisplayManager {

    /// Virtual displays Hydra created this session (strong refs keep them alive).
    private(set) var virtualHandles: [VirtualDisplayHandle] = []

    /// Every screen currently attached, refreshed on hardware changes.
    private(set) var allDisplays: [DisplayInfo] = []

    /// Surfaced to the UI when something goes wrong.
    var lastError: String?

    /// Whether the private virtual-display API is usable on this macOS.
    let isVirtualDisplaySupported = VirtualDisplayBridge.isAvailable

    private var reconfigObserver: Any?

    init() {
        refresh()
        // Re-enumerate whenever the display topology changes.
        reconfigObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    // MARK: - Virtual display lifecycle

    @discardableResult
    func createVirtualDisplay(_ spec: VirtualDisplaySpec) -> VirtualDisplayHandle? {
        do {
            let handle = try VirtualDisplayBridge.create(spec)
            virtualHandles.append(handle)
            // Give CoreGraphics a beat to register the new display.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.refresh()
            }
            return handle
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func remove(_ handle: VirtualDisplayHandle) {
        // Dropping the only strong reference tears the display down.
        virtualHandles.removeAll { $0.id == handle.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.refresh()
        }
    }

    func removeAll() {
        virtualHandles.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.refresh()
        }
    }

    func handle(for displayID: CGDirectDisplayID) -> VirtualDisplayHandle? {
        virtualHandles.first { $0.cgDisplayID == displayID }
    }

    // MARK: - Mirroring (public CGConfigureDisplayMirrorOfDisplay)

    /// Mirror `display` so it shows the contents of `source`.
    func mirror(_ display: CGDirectDisplayID, onto source: CGDirectDisplayID) {
        withConfiguration { config in
            CGConfigureDisplayMirrorOfDisplay(config, display, source)
        }
    }

    func stopMirroring(_ display: CGDirectDisplayID) {
        withConfiguration { config in
            CGConfigureDisplayMirrorOfDisplay(config, display, kCGNullDirectDisplay)
        }
    }

    // MARK: - Arrangement (public CGConfigureDisplayOrigin)

    func setOrigin(_ display: CGDirectDisplayID, to point: CGPoint) {
        withConfiguration { config in
            CGConfigureDisplayOrigin(config, display, Int32(point.x), Int32(point.y))
        }
    }

    /// Runs a block inside a begin/complete configuration transaction.
    private func withConfiguration(_ body: (CGDisplayConfigRef?) -> CGError) {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            lastError = "Could not begin a display configuration transaction."
            return
        }
        let err = body(config)
        guard err == .success else {
            CGCancelDisplayConfiguration(config)
            lastError = "Display configuration was rejected (CGError \(err.rawValue))."
            return
        }
        let result = CGCompleteDisplayConfiguration(config, .permanently)
        if result != .success {
            lastError = "Could not apply the display configuration (CGError \(result.rawValue))."
        }
        refresh()
    }

    // MARK: - Enumeration

    func refresh() {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { allDisplays = []; return }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)

        let mainID = CGMainDisplayID()
        let hydraIDs = Set(virtualHandles.map(\.cgDisplayID))

        allDisplays = ids.map { id in
            let mirrorSource = CGDisplayMirrorsDisplay(id)
            return DisplayInfo(
                id: id,
                name: Self.localizedName(for: id, hydra: hydraIDs.contains(id),
                                         hydraName: handle(for: id)?.spec.name),
                pixelWidth: CGDisplayPixelsWide(id),
                pixelHeight: CGDisplayPixelsHigh(id),
                isVirtualHydra: hydraIDs.contains(id),
                isMirrored: mirrorSource != kCGNullDirectDisplay,
                mirrorSourceID: mirrorSource == kCGNullDirectDisplay ? nil : mirrorSource,
                origin: CGDisplayBounds(id).origin,
                isMain: id == mainID
            )
        }
    }

    private static func localizedName(for id: CGDirectDisplayID,
                                      hydra: Bool,
                                      hydraName: String?) -> String {
        if hydra, let hydraName { return hydraName }
        // Map the CG display ID to its NSScreen to read the human-readable name.
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               number == id {
                return screen.localizedName
            }
        }
        return "Display \(id)"
    }
}
