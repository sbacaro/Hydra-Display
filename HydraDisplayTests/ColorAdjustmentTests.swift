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

@Suite("Color adjustment")
struct ColorAdjustmentTests {

    @Test("A default adjustment is neutral")
    func defaultIsNeutral() {
        #expect(ColorAdjustment().isNeutral)
    }

    @Test("Dimming or tinting makes it non-neutral")
    func nonNeutral() {
        #expect(ColorAdjustment(brightness: 0.5, temperature: 0).isNeutral == false)
        #expect(ColorAdjustment(brightness: 1.0, temperature: -0.4).isNeutral == false)
    }

    @Test("Tiny deviations are still treated as neutral")
    func toleranceIsNeutral() {
        #expect(ColorAdjustment(brightness: 0.9999, temperature: 0.0005).isNeutral)
    }

    @Test("Round-trips through Codable")
    func codable() throws {
        let sample = ColorAdjustment(brightness: 0.6, temperature: -0.3)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(ColorAdjustment.self, from: data)
        #expect(decoded == sample)
    }
}
