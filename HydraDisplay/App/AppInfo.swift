//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  AppInfo.swift
//  Hydra Display
//
//  SINGLE SOURCE OF TRUTH for the app's "edition": its name, version, links,
//  and legal strings. Every part of the app (window titles, the About window,
//  the menu bar, etc.) reads from here — never hard-code these elsewhere.
//
//  Note: the version *number* is owned by the Xcode project
//  (MARKETING_VERSION / CURRENT_PROJECT_VERSION) and surfaced here by reading
//  the generated Info.plist, so the binary and the UI can never disagree.
//

import Foundation

enum AppInfo {

    // MARK: Identity

    /// Display name of the app.
    static let name = "Hydra Display"

    /// One-line description shown in the About window and the README.
    static let tagline = "Create virtual displays on macOS."

    /// SF Symbol used as the app's glyph in the menu bar and About window.
    static let symbol = "rectangle.on.rectangle.angled"

    /// Reverse-DNS bundle identifier (falls back if read before launch).
    static let bundleIdentifier =
        Bundle.main.bundleIdentifier ?? "app.hydradisplay.HydraDisplay"

    // MARK: Edition / version

    /// Marketing version, e.g. "0.1.0" (CFBundleShortVersionString).
    static let version =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

    /// Build number, e.g. "1" (CFBundleVersion).
    static let build =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

    /// "Version 0.1.0 (1)" — ready for display.
    static var versionString: String { "Version \(version) (\(build))" }

    /// "v0.1.0" — short form for tags and badges.
    static var shortVersionTag: String { "v\(version)" }

    /// Minimum supported OS, shown in About.
    static let minimumOS = "macOS 26.0 (Tahoe) or later"

    // MARK: Legal

    static let copyright = "Copyright © 2026 Hydra Display contributors"
    static let licenseName = "GNU General Public License v3.0 or later"
    static let licenseSPDX = "GPL-3.0-or-later"

    // MARK: Links

    static let repositoryURL =
        URL(string: "https://github.com/sbacaro/Hydra-Display")!
    static let releasesURL =
        URL(string: "https://github.com/sbacaro/Hydra-Display/releases")!
    static let issuesURL =
        URL(string: "https://github.com/sbacaro/Hydra-Display/issues/new/choose")!
    static let licenseURL =
        URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!
}
