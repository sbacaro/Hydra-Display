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

@Suite("Virtual display model")
struct VirtualDisplayModelTests {

    @Test("Mode derives id, label and HiDPI point size")
    func modeDerivations() {
        let mode = VirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60)
        #expect(mode.id == "1920x1080@60")
        #expect(mode.label == "1920 × 1080")
        #expect(mode.hiDPIPointSize.w == 960)
        #expect(mode.hiDPIPointSize.h == 540)
    }

    @Test("Mode survives a Codable round-trip")
    func modeCodable() throws {
        let mode = VirtualDisplayMode(width: 2560, height: 1440, refreshRate: 120)
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(VirtualDisplayMode.self, from: data)
        #expect(decoded == mode)
    }

    @Test("Spec computes the largest framebuffer from its modes")
    func specMaxPixels() {
        let spec = VirtualDisplaySpec(
            name: "Test",
            widthMillimeters: 600, heightMillimeters: 340,
            hiDPI: true,
            modes: [
                VirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60),
                VirtualDisplayMode(width: 3840, height: 2160, refreshRate: 60),
                VirtualDisplayMode(width: 2560, height: 1440, refreshRate: 60),
            ])
        #expect(spec.maxPixelsWide == 3840)
        #expect(spec.maxPixelsHigh == 2160)
    }

    @Test("Spec falls back to 1920×1080 when it has no modes")
    func specEmptyModes() {
        let spec = VirtualDisplaySpec(name: "Empty", widthMillimeters: 1,
                                      heightMillimeters: 1, hiDPI: false, modes: [])
        #expect(spec.maxPixelsWide == 1920)
        #expect(spec.maxPixelsHigh == 1080)
    }

    @Test("Spec is Equatable and Codable")
    func specCodableEquatable() throws {
        let spec = VirtualDisplaySpec(
            name: "4K Retina",
            widthMillimeters: 600, heightMillimeters: 340,
            hiDPI: true,
            modes: ResolutionPresets.defaultModes)
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(VirtualDisplaySpec.self, from: data)
        #expect(decoded == spec)

        var other = spec
        other.name = "Changed"
        #expect(other != spec)
    }
}
