//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

import Testing
@testable import HydraDisplay

@Suite("Resolution presets")
struct ResolutionPresetsTests {

    @Test("The catalogue is populated")
    func catalogueIsPopulated() {
        #expect(!ResolutionPresets.groups.isEmpty)
        #expect(!ResolutionPresets.all.isEmpty)
        // `all` is the flattened union of every group.
        let flattened = ResolutionPresets.groups.flatMap(\.presets).count
        #expect(ResolutionPresets.all.count == flattened)
    }

    @Test("Default modes are sensible")
    func defaultModes() {
        #expect(ResolutionPresets.defaultModes.count == 3)
        #expect(ResolutionPresets.defaultModes.allSatisfy { $0.width > 0 && $0.height > 0 })
        // Default modes default to 60 Hz.
        #expect(ResolutionPresets.defaultModes.allSatisfy { $0.refreshRate == 60 })
    }

    @Test("Aspect ratio is reduced correctly", arguments: [
        (1920, 1080, "16:9"),
        (1280, 720, "16:9"),
        (3840, 2160, "16:9"),
        (2560, 1600, "8:5"),
        (3440, 1440, "43:18"),
    ])
    func aspectRatio(width: Int, height: Int, expected: String) {
        let preset = ResolutionPresets.Preset(name: "x", width: width, height: height)
        #expect(preset.aspect == expected)
    }

    @Test("Preset builds a 60 Hz mode by default")
    func presetMode() {
        let preset = ResolutionPresets.Preset(name: "FHD", width: 1920, height: 1080)
        let mode = preset.mode()
        #expect(mode.width == 1920)
        #expect(mode.height == 1080)
        #expect(mode.refreshRate == 60)
        #expect(preset.mode(refreshRate: 120).refreshRate == 120)
    }

    @Test("Physical millimetres are positive and HiDPI panels are denser")
    func millimetres() {
        let standard = ResolutionPresets.millimeters(for: 1920, height: 1080, hiDPI: false)
        let retina = ResolutionPresets.millimeters(for: 1920, height: 1080, hiDPI: true)
        #expect(standard.w > 0 && standard.h > 0)
        #expect(retina.w > 0 && retina.h > 0)
        // Same pixel count at a higher ppi ⇒ a physically smaller panel.
        #expect(retina.w < standard.w)
        #expect(retina.h < standard.h)
    }
}
