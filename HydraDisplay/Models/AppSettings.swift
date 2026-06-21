//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  AppSettings.swift
//  Hydra Display
//
//  User preferences, backed by UserDefaults. Also owns the "launch at login"
//  registration via ServiceManagement.
//

import Foundation
import Observation
import ServiceManagement
import Carbon.HIToolbox

@Observable
@MainActor
final class AppSettings {

    enum Keys {
        static let restoreOnLaunch = "restoreVirtualDisplaysOnLaunch"
        static let autoCheckUpdates = "automaticallyCheckForUpdates"
        static let onboardingDone = "hasCompletedOnboarding"
        static let globalHotkeys = "enableGlobalHotkeys"
    }

    /// Whether saved virtual displays are recreated automatically on launch.
    var restoreOnLaunch: Bool {
        didSet { UserDefaults.standard.set(restoreOnLaunch, forKey: Keys.restoreOnLaunch) }
    }

    /// Whether the app checks GitHub for a newer release on launch.
    var autoCheckUpdates: Bool {
        didSet { UserDefaults.standard.set(autoCheckUpdates, forKey: Keys.autoCheckUpdates) }
    }

    /// Whether the first-run welcome has been dismissed.
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboardingDone) }
    }

    /// Whether system-wide keyboard shortcuts are active.
    var enableGlobalHotkeys: Bool {
        didSet {
            UserDefaults.standard.set(enableGlobalHotkeys, forKey: Keys.globalHotkeys)
            applyHotkeys(enableGlobalHotkeys)
        }
    }

    /// Whether the app is registered to start at login.
    var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    /// Surfaced to the UI if toggling login registration fails.
    var lastError: String?

    init() {
        // Default toggles to ON for first run.
        if UserDefaults.standard.object(forKey: Keys.restoreOnLaunch) == nil {
            UserDefaults.standard.set(true, forKey: Keys.restoreOnLaunch)
        }
        if UserDefaults.standard.object(forKey: Keys.autoCheckUpdates) == nil {
            UserDefaults.standard.set(true, forKey: Keys.autoCheckUpdates)
        }
        restoreOnLaunch = UserDefaults.standard.bool(forKey: Keys.restoreOnLaunch)
        autoCheckUpdates = UserDefaults.standard.bool(forKey: Keys.autoCheckUpdates)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.onboardingDone)
        enableGlobalHotkeys = UserDefaults.standard.bool(forKey: Keys.globalHotkeys)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        applyHotkeys(enableGlobalHotkeys)
    }

    // MARK: - Global hot keys

    private func applyHotkeys(_ enabled: Bool) {
        guard !AppEnvironment.isUnitTesting else { return }
        HotKeyCenter.shared.unregisterAll()
        guard enabled else { return }
        let mods = UInt32(cmdKey | optionKey | controlKey)
        HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_N), modifiers: mods) {
            DisplayManager.shared.createVirtualDisplay(QuickResolution.retina4K.spec)
        }
        HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_R), modifiers: mods) {
            DisplayManager.shared.removeAll()
        }
    }

    /// Convenience for code that only needs to read the stored flag.
    static var restoreOnLaunchEnabled: Bool {
        UserDefaults.standard.object(forKey: Keys.restoreOnLaunch) as? Bool ?? true
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            lastError = "Couldn't update “Open at Login”: \(error.localizedDescription)"
            // Re-sync the toggle with the real state.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
