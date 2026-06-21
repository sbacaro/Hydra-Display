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

@Suite("Display profiles")
struct ProfileStoreTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("HydraProfileTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }

    private var sample: [DisplayProfile] {
        [
            DisplayProfile(name: "Studio", specs: [
                VirtualDisplaySpec(name: "4K", widthMillimeters: 600, heightMillimeters: 340,
                                   hiDPI: true, modes: ResolutionPresets.defaultModes),
            ]),
            DisplayProfile(name: "Travel", specs: []),
        ]
    }

    @Test("Encode/decode preserves profiles")
    func encodeDecode() throws {
        let profiles = sample   // capture once: `sample` mints fresh ids on each access
        let data = try ProfileStore.encode(profiles)
        let decoded = try ProfileStore.decode(data)
        #expect(decoded == profiles)
    }

    @Test("Save then load round-trips")
    func saveLoad() {
        let profiles = sample   // capture once: `sample` mints fresh ids on each access
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        ProfileStore.save(profiles, to: url)
        #expect(ProfileStore.load(from: url) == profiles)
    }

    @Test("Loading a missing file returns no profiles")
    func loadMissing() {
        #expect(ProfileStore.load(from: tempURL()).isEmpty)
    }

    @Test("Profile reports its display count")
    func displayCount() {
        #expect(sample[0].displayCount == 1)
        #expect(sample[1].displayCount == 0)
    }
}
