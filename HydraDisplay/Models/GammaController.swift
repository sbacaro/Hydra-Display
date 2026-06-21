//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  GammaController.swift
//  Hydra Display
//
//  Per-display software dimming and color temperature using the *public*
//  CoreGraphics gamma API (`CGSetDisplayTransferByFormula`). It needs no DDC,
//  no entitlement, and works on physical and virtual displays alike.
//
//  Adjustments are keyed by the display's stable UUID and persisted, then
//  re-applied whenever the OS resets the gamma tables (display reconfiguration
//  or wake from sleep). Quitting the app restores every display to normal.
//

import AppKit
import CoreGraphics
import Observation

/// One display's software color adjustment. `brightness` scales output (a soft
/// dim, never fully black); `temperature` shifts the white point from warm
/// (−1, less blue) to cool (+1, less red). Zero is the display's normal look.
struct ColorAdjustment: Codable, Equatable {
    var brightness: Double = 1.0       // 0.2 … 1.0
    var temperature: Double = 0.0      // −1.0 (warm) … 1.0 (cool)

    static let minBrightness = 0.2

    var isNeutral: Bool {
        abs(brightness - 1.0) < 0.001 && abs(temperature) < 0.001
    }
}

@MainActor
@Observable
final class GammaController {

    static let shared = GammaController()

    /// Adjustments keyed by display UUID string (stable across IDs/reboots).
    private var adjustments: [String: ColorAdjustment]
    private static let defaultsKey = "displayColorAdjustments"

    private init() {
        adjustments = Self.loadPersisted()

        let nc = NotificationCenter.default
        // The OS wipes gamma tables on these — re-apply ours afterwards.
        nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                       object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reapplyAll() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reapplyAll() }
        }
        // Leave displays in their normal state when the app exits.
        nc.addObserver(forName: NSApplication.willTerminateNotification,
                       object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { CGDisplayRestoreColorSyncSettings() }
        }

        if !AppEnvironment.isUnitTesting { reapplyAll() }
    }

    // MARK: - Queries

    func adjustment(for id: CGDirectDisplayID) -> ColorAdjustment {
        adjustments[Self.key(for: id)] ?? ColorAdjustment()
    }

    func isAdjusted(_ id: CGDirectDisplayID) -> Bool {
        !(adjustments[Self.key(for: id)]?.isNeutral ?? true)
    }

    // MARK: - Mutations

    func setBrightness(_ value: Double, for id: CGDirectDisplayID) {
        update(id) { $0.brightness = min(max(value, ColorAdjustment.minBrightness), 1.0) }
    }

    func setTemperature(_ value: Double, for id: CGDirectDisplayID) {
        update(id) { $0.temperature = min(max(value, -1.0), 1.0) }
    }

    /// Return one display to its normal brightness and white point.
    func reset(_ id: CGDirectDisplayID) {
        adjustments[Self.key(for: id)] = nil
        persist()
        reapplyAll()   // restores baseline, then re-applies the others
    }

    /// Return every display to normal.
    func resetAll() {
        adjustments.removeAll()
        persist()
        CGDisplayRestoreColorSyncSettings()
    }

    private func update(_ id: CGDirectDisplayID, _ mutate: (inout ColorAdjustment) -> Void) {
        var adj = adjustment(for: id)
        mutate(&adj)
        let key = Self.key(for: id)
        if adj.isNeutral {
            adjustments[key] = nil
            CGDisplayRestoreColorSyncSettings()   // back to calibrated baseline…
            reapplyOthers(excluding: id)          // …keeping every other display's look
        } else {
            adjustments[key] = adj
            apply(adj, to: id)
        }
        persist()
    }

    // MARK: - Applying gamma

    private func apply(_ adj: ColorAdjustment, to id: CGDirectDisplayID) {
        let t = adj.temperature
        let warm = max(0.0, -t)    // pull blue down
        let cool = max(0.0,  t)    // pull red down
        let r = adj.brightness * (1.0 - cool * 0.5)
        let g = adj.brightness * (1.0 - warm * 0.15 - cool * 0.15)
        let b = adj.brightness * (1.0 - warm * 0.5)
        _ = CGSetDisplayTransferByFormula(
            id,
            0.0, CGGammaValue(r), 1.0,
            0.0, CGGammaValue(g), 1.0,
            0.0, CGGammaValue(b), 1.0)
    }

    /// Restore the calibrated baseline for all displays, then re-apply ours.
    func reapplyAll() {
        CGDisplayRestoreColorSyncSettings()
        reapplyOthers(excluding: nil)
    }

    private func reapplyOthers(excluding skip: CGDirectDisplayID?) {
        for id in Self.activeDisplays() where id != skip {
            let adj = adjustment(for: id)
            if !adj.isNeutral { apply(adj, to: id) }
        }
    }

    // MARK: - Display enumeration & identity

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids
    }

    private static func key(for id: CGDirectDisplayID) -> String {
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "cg-\(id)"
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(adjustments) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private static func loadPersisted() -> [String: ColorAdjustment] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let dict = try? JSONDecoder().decode([String: ColorAdjustment].self, from: data)
        else { return [:] }
        return dict
    }
}
