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

@Suite("Updater")
struct UpdaterTests {

    @Test("Semantic version comparison", arguments: [
        ("0.2.0", "0.1.0", true),
        ("0.1.1", "0.1.0", true),
        ("1.0.0", "0.9.9", true),
        ("0.10.0", "0.9.0", true),     // numeric, not lexical
        ("1.0.1", "1.0", true),
        ("0.1.0", "0.1.0", false),
        ("0.1.0", "0.2.0", false),
        ("1.0", "1.0.0", false),       // equal once padded
        ("0.9.0", "0.10.0", false),
    ])
    func isNewer(remote: String, local: String, expected: Bool) {
        #expect(Updater.isNewer(remote, than: local) == expected)
    }

    @Test("GitHub release JSON decodes and selects the .app.zip asset")
    func decodeRelease() throws {
        let json = """
        {
          "tag_name": "v0.2.0",
          "html_url": "https://github.com/sbacaro/Hydra-Display/releases/tag/v0.2.0",
          "body": "Release notes here",
          "assets": [
            { "name": "SHA256SUMS.txt",
              "browser_download_url": "https://example.com/SHA256SUMS.txt" },
            { "name": "HydraDisplay-0.2.0.dmg",
              "browser_download_url": "https://example.com/HydraDisplay-0.2.0.dmg" },
            { "name": "HydraDisplay-0.2.0.app.zip",
              "browser_download_url": "https://example.com/HydraDisplay-0.2.0.app.zip" }
          ]
        }
        """
        let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))

        #expect(release.tagName == "v0.2.0")
        #expect(release.version == "0.2.0")               // leading "v" stripped
        #expect(release.assets.count == 3)
        #expect(release.appZipAsset?.name == "HydraDisplay-0.2.0.app.zip")
        #expect(release.appZipAsset?.browserDownloadURL.absoluteString
                == "https://example.com/HydraDisplay-0.2.0.app.zip")
    }

    @Test("appZipAsset falls back to any .zip and ignores .dmg")
    func appZipFallback() throws {
        let json = """
        { "tag_name": "1.0.0", "html_url": "https://x", "assets": [
          { "name": "thing.dmg", "browser_download_url": "https://x/thing.dmg" },
          { "name": "thing.zip", "browser_download_url": "https://x/thing.zip" }
        ] }
        """
        let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
        #expect(release.version == "1.0.0")               // no "v" prefix to strip
        #expect(release.appZipAsset?.name == "thing.zip")
    }

    @MainActor
    @Test("A fresh updater starts idle and not busy")
    func initialState() {
        let updater = Updater()
        #expect(updater.phase == .idle)
        #expect(updater.isBusy == false)
        #expect(updater.availableVersion == nil)
    }
}
