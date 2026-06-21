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

@Suite("Display persistence")
struct DisplayStoreTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("HydraStoreTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("virtual-displays.json")
    }

    private var sampleSpecs: [VirtualDisplaySpec] {
        [
            VirtualDisplaySpec(name: "4K", widthMillimeters: 600, heightMillimeters: 340,
                               hiDPI: true, modes: ResolutionPresets.defaultModes),
            VirtualDisplaySpec(name: "1080p", widthMillimeters: 500, heightMillimeters: 280,
                               hiDPI: false,
                               modes: [VirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60)]),
        ]
    }

    @Test("Encode/decode is lossless")
    func encodeDecode() throws {
        let data = try DisplayStore.encode(sampleSpecs)
        let decoded = try DisplayStore.decode(data)
        #expect(decoded == sampleSpecs)
    }

    @Test("Save then load returns the same specs")
    func saveLoadRoundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        DisplayStore.save(sampleSpecs, to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))

        let loaded = DisplayStore.load(from: url)
        #expect(loaded == sampleSpecs)
    }

    @Test("Loading a missing file yields an empty array")
    func loadMissing() {
        let url = tempURL()
        #expect(DisplayStore.load(from: url).isEmpty)
    }

    @Test("Saving an empty array clears the displays")
    func saveEmpty() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        DisplayStore.save(sampleSpecs, to: url)
        DisplayStore.save([], to: url)
        #expect(DisplayStore.load(from: url).isEmpty)
    }
}
