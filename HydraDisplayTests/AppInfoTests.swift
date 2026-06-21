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

@Suite("App info")
struct AppInfoTests {

    @Test("Identity constants are correct")
    func identity() {
        #expect(AppInfo.name == "Hydra Display")
        #expect(AppInfo.licenseSPDX == "GPL-3.0-or-later")
        #expect(!AppInfo.tagline.isEmpty)
        #expect(AppInfo.symbol == "rectangle.on.rectangle.angled")
    }

    @Test("Version strings are derived consistently")
    func versionStrings() {
        #expect(!AppInfo.version.isEmpty)
        #expect(AppInfo.versionString == "Version \(AppInfo.version) (\(AppInfo.build))")
        #expect(AppInfo.shortVersionTag == "v\(AppInfo.version)")
    }

    @Test("Links point at the project repository")
    func links() {
        #expect(AppInfo.repositoryURL.host == "github.com")
        #expect(AppInfo.repositoryURL.absoluteString.contains("sbacaro/Hydra-Display"))
        #expect(AppInfo.releasesURL.absoluteString.hasSuffix("/releases"))
        #expect(AppInfo.licenseURL.absoluteString.contains("gnu.org"))
    }
}
