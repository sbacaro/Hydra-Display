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

@Suite("Diagnostics")
struct DiagnosticsTests {

    @Test("Suggested filename is a timestamped .txt")
    func suggestedFilename() {
        let name = Diagnostics.suggestedFilename
        #expect(name.hasPrefix("HydraDisplay-Diagnostics-"))
        #expect(name.hasSuffix(".txt"))
        // yyyy-MM-dd-HHmm → 15 characters between the prefix and ".txt".
        let stamp = name
            .replacingOccurrences(of: "HydraDisplay-Diagnostics-", with: "")
            .replacingOccurrences(of: ".txt", with: "")
        #expect(stamp.count == 15)
    }
}
