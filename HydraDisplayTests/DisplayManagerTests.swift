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

@MainActor
@Suite("Display manager")
struct DisplayManagerTests {

    @Test("A new manager has no virtual displays")
    func freshManager() {
        let manager = DisplayManager(autoRestore: false)
        #expect(manager.virtualHandles.isEmpty)
        #expect(manager.handle(for: 0) == nil)
    }

    @Test("Enumeration produces a valid snapshot")
    func enumeration() {
        let manager = DisplayManager(autoRestore: false)
        manager.refresh()
        // On real hardware there is at least one screen; in a headless runner
        // the list may be empty — either way the snapshot must be consistent.
        for info in manager.allDisplays {
            #expect(info.pixelWidth >= 0)
            #expect(info.pixelHeight >= 0)
            #expect(info.resolutionLabel == "\(info.pixelWidth) × \(info.pixelHeight)")
        }
        // At most one display is flagged as the main one.
        #expect(manager.allDisplays.filter(\.isMain).count <= 1)
    }

    @Test("removeAll keeps the handle list empty")
    func removeAll() {
        let manager = DisplayManager(autoRestore: false)
        manager.removeAll()
        #expect(manager.virtualHandles.isEmpty)
    }

    @Test("Mirroring an invalid display does not crash")
    func invalidMirror() {
        let manager = DisplayManager(autoRestore: false)
        // 0 is not a valid display id; this must fail gracefully, not trap.
        manager.stopMirroring(0)
        #expect(Bool(true))
    }
}

@Suite("Display info")
struct DisplayInfoTests {

    @Test("Resolution label is formatted from pixel dimensions")
    func resolutionLabel() {
        let info = DisplayInfo(
            id: 1, name: "Test", pixelWidth: 2560, pixelHeight: 1440,
            isVirtualHydra: true, isMirrored: false, mirrorSourceID: nil,
            origin: .zero, isMain: true)
        #expect(info.resolutionLabel == "2560 × 1440")
    }
}
