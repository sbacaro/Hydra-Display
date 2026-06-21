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

@Suite("PIP capture sizing")
struct PiPStreamTests {

    @Test("Sizes under the cap are unchanged")
    func underCap() {
        let s = PiPStreamController.cappedSize(1920, 1080)
        #expect(s.w == 1920 && s.h == 1080)
    }

    @Test("Oversized captures are scaled down, keeping aspect ratio")
    func overCap() {
        // A Retina full-screen video: 2560×1440 points × 2 = 5120×2880.
        let s = PiPStreamController.cappedSize(5120, 2880)
        #expect(max(s.w, s.h) <= 2560)
        // 16:9 preserved.
        #expect(s.w == 2560 && s.h == 1440)
    }

    @Test("Degenerate sizes never go below 2px")
    func floor() {
        let s = PiPStreamController.cappedSize(0, 0)
        #expect(s.w >= 2 && s.h >= 2)
    }
}
