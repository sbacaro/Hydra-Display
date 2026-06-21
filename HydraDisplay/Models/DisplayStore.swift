//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  DisplayStore.swift
//  Hydra Display
//
//  Persists the specs of created virtual displays to disk so they can be
//  recreated on the next launch. Stored as JSON in Application Support.
//

import Foundation

enum DisplayStore {

    /// ~/Library/Application Support/Hydra Display/virtual-displays.json
    static var defaultURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Hydra Display", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("virtual-displays.json")
    }

    /// Encode specs to JSON `Data` (pure, easily testable).
    static func encode(_ specs: [VirtualDisplaySpec]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(specs)
    }

    /// Decode specs from JSON `Data`.
    static func decode(_ data: Data) throws -> [VirtualDisplaySpec] {
        try JSONDecoder().decode([VirtualDisplaySpec].self, from: data)
    }

    /// Persist the given specs, replacing any previous file. Failures are ignored
    /// (persistence is a convenience, never a hard requirement). The destination
    /// URL is injectable so tests can use a temporary location.
    static func save(_ specs: [VirtualDisplaySpec], to url: URL = defaultURL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encode(specs).write(to: url, options: .atomic)
        } catch {
            // Non-fatal.
        }
    }

    /// Load previously-saved specs, or an empty array if none/unreadable.
    static func load(from url: URL = defaultURL) -> [VirtualDisplaySpec] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decode(data)) ?? []
    }
}
