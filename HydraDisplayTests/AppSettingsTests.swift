//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

import Foundation
import Testing
@testable import HydraDisplay

@MainActor
@Suite("App settings")
struct AppSettingsTests {

    private let key = AppSettings.Keys.restoreOnLaunch

    @Test("restoreOnLaunchEnabled defaults to true when unset")
    func defaultRestore() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer { defaults.set(original, forKey: key) }

        defaults.removeObject(forKey: key)
        #expect(AppSettings.restoreOnLaunchEnabled == true)

        defaults.set(false, forKey: key)
        #expect(AppSettings.restoreOnLaunchEnabled == false)

        defaults.set(true, forKey: key)
        #expect(AppSettings.restoreOnLaunchEnabled == true)
    }

    @Test("Settings initialise without throwing and expose Bool flags")
    func initialises() {
        let settings = AppSettings()
        // Reading the flags is enough to prove the object initialised cleanly.
        _ = settings.restoreOnLaunch
        _ = settings.autoCheckUpdates
        _ = settings.launchAtLogin
        #expect(settings.lastError == nil)
    }
}
