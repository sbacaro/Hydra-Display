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

    /// Shared instance used by the UI and by App Intents so both operate on the
    /// same set of virtual displays.
    static let shared = DisplayManager()

    /// Virtual displays Hydra created this session (strong refs keep them alive).
    private(set) var virtualHandles: [VirtualDisplayHandle] = []

    /// Every screen currently attached, refreshed on hardware changes.
    private(set) var allDisplays: [DisplayInfo] = []

    /// Saved, named sets of virtual displays the user can re-apply.
    private(set) var profiles: [DisplayProfile] = []

    /// Surfaced to the UI when something goes wrong.
    var lastError: String?

    /// Whether the private virtual-display API is usable on this macOS.
    let isVirtualDisplaySupported = VirtualDisplayBridge.isAvailable

    private var reconfigObserver: Any?
    private var didRestore = false

    init(autoRestore: Bool = true) {
        profiles = ProfileStore.load()
        refresh()
        // Re-enumerate whenever the display topology changes.
        reconfigObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // Recreate persisted displays shortly after launch (once CoreGraphics is ready).
        // Disabled in tests so unit runs never touch real hardware.
        if autoRestore {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(600))
                self?.restoreIfNeeded()
            }
        }
    }

    // MARK: - Virtual display lifecycle

    @discardableResult
    func createVirtualDisplay(_ spec: VirtualDisplaySpec) -> VirtualDisplayHandle? {
        do {
            let handle = try VirtualDisplayBridge.create(spec)
            virtualHandles.append(handle)
            persist()
            // Give CoreGraphics a beat to register the new display.
            scheduleRefresh(after: .milliseconds(300))
            return handle
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func remove(_ handle: VirtualDisplayHandle) {
        // Dropping the only strong reference tears the display down.
        virtualHandles.removeAll { $0.id == handle.id }
        persist()
        scheduleRefresh(after: .milliseconds(200))
    }

    func removeAll() {
        virtualHandles.removeAll()
        persist()
        scheduleRefresh(after: .milliseconds(200))
    }

    func handle(for displayID: CGDirectDisplayID) -> VirtualDisplayHandle? {
        virtualHandles.first { $0.cgDisplayID == displayID }
    }

    // MARK: - Persistence

    /// Save the current set of virtual displays to disk.
    private func persist() {
        DisplayStore.save(virtualHandles.map(\.spec))
    }

    /// Recreate persisted virtual displays once, if the feature is enabled.
    func restoreIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        guard !AppEnvironment.isUnitTesting,
              isVirtualDisplaySupported,
              AppSettings.restoreOnLaunchEnabled else { return }
        for spec in DisplayStore.load() where !virtualHandles.contains(where: { $0.spec == spec }) {
            createVirtualDisplay(spec)
        }
    }

    // MARK: - Profiles

    /// Save the current virtual displays as a named profile.
    @discardableResult
    func saveCurrentAsProfile(named name: String) -> DisplayProfile? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let profile = DisplayProfile(name: trimmed, specs: virtualHandles.map(\.spec))
        profiles.append(profile)
        ProfileStore.save(profiles)
        return profile
    }

    /// Replace the current virtual displays with the ones in a profile.
    func applyProfile(_ profile: DisplayProfile) {
        removeAll()
        for spec in profile.specs { createVirtualDisplay(spec) }
    }

    func deleteProfile(_ profile: DisplayProfile) {
        profiles.removeAll { $0.id == profile.id }
        ProfileStore.save(profiles)
    }

    /// Re-enumerate after a short delay, staying on the main actor (Swift 6 safe).
    private func scheduleRefresh(after delay: Duration) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            self?.refresh()
        }
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

    // MARK: - Resolution (active CGDisplayMode, public API)

    /// All desktop-usable hardware modes for a display.
    private func hardwareModes(for displayID: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!] as CFDictionary
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode]
        else { return [] }
        return modes.filter { $0.isUsableForDesktopGUI() }
    }

    /// The resolutions a display can switch to, de-duplicated and sorted largest-first.
    func availableModes(for displayID: CGDirectDisplayID) -> [ScreenMode] {
        var seen = Set<String>()
        return hardwareModes(for: displayID)
            .map { ScreenMode($0) }
            .filter { seen.insert($0.id).inserted }
            .sorted {
                if $0.pixelWidth != $1.pixelWidth { return $0.pixelWidth > $1.pixelWidth }
                if $0.pixelHeight != $1.pixelHeight { return $0.pixelHeight > $1.pixelHeight }
                return $0.refreshRate > $1.refreshRate
            }
    }

    /// The display's currently active resolution.
    func currentMode(for displayID: CGDirectDisplayID) -> ScreenMode? {
        CGDisplayCopyDisplayMode(displayID).map { ScreenMode($0) }
    }

    /// Switch a display to a different active resolution.
    func setMode(_ target: ScreenMode, for displayID: CGDirectDisplayID) {
        guard let match = hardwareModes(for: displayID).first(where: { target.matches($0) }) else {
            lastError = "That resolution is no longer available."
            return
        }
        withConfiguration { config in
            CGConfigureDisplayWithDisplayMode(config, displayID, match, nil)
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
