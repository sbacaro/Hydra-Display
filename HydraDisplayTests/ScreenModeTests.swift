//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

import Foundation
import CoreGraphics
import Testing
@testable import HydraDisplay

@Suite("Screen mode")
struct ScreenModeTests {

    @Test("HiDPI mode derives label, id and menu label")
    func hiDPIMode() {
        let mode = ScreenMode(width: 1512, height: 982,
                              pixelWidth: 3024, pixelHeight: 1964, refreshRate: 60)
        #expect(mode.isHiDPI)
        #expect(mode.label == "1512 × 982")
        #expect(mode.id == "3024x1964@60")
        #expect(mode.menuLabel == "1512 × 982 · HiDPI")
    }

    @Test("Standard mode is not HiDPI and hides the 60 Hz suffix")
    func standardMode() {
        let mode = ScreenMode(width: 1920, height: 1080,
                              pixelWidth: 1920, pixelHeight: 1080, refreshRate: 60)
        #expect(mode.isHiDPI == false)
        #expect(mode.menuLabel == "1920 × 1080")
    }

    @Test("Non-standard refresh rate is shown")
    func highRefresh() {
        let mode = ScreenMode(width: 2560, height: 1440,
                              pixelWidth: 2560, pixelHeight: 1440, refreshRate: 120)
        #expect(mode.menuLabel == "2560 × 1440 · 120 Hz")
    }

    @Test("Distinct pixel sizes are distinct values")
    func distinctness() {
        let a = ScreenMode(width: 1920, height: 1080,
                           pixelWidth: 1920, pixelHeight: 1080, refreshRate: 60)
        let b = ScreenMode(width: 1920, height: 1080,
                           pixelWidth: 3840, pixelHeight: 2160, refreshRate: 60)
        #expect(a != b)
        #expect(a.id != b.id)
    }
}

@MainActor
@Suite("Display manager — resolution")
struct DisplayManagerResolutionTests {

    @Test("Available modes are well-formed for the main display")
    func availableModes() {
        let manager = DisplayManager(autoRestore: false)
        let modes = manager.availableModes(for: CGMainDisplayID())
        // Headless CI may return none; whatever comes back must be valid and unique.
        for mode in modes {
            #expect(mode.width > 0 && mode.height > 0)
            #expect(mode.pixelWidth >= mode.width)
        }
        #expect(Set(modes.map(\.id)).count == modes.count)
    }
}
