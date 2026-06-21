//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  DisplayProfile.swift
//  Hydra Display
//
//  A named set of virtual displays the user can save and re-apply with one
//  click, persisted alongside the session displays.
//

import Foundation

struct DisplayProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var specs: [VirtualDisplaySpec]
    var createdAt = Date()

    var displayCount: Int { specs.count }
}

enum ProfileStore {

    /// ~/Library/Application Support/Hydra Display/profiles.json
    static var defaultURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Hydra Display", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profiles.json")
    }

    static func encode(_ profiles: [DisplayProfile]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Default Date coding (reference-date Double) round-trips exactly.
        return try encoder.encode(profiles)
    }

    static func decode(_ data: Data) throws -> [DisplayProfile] {
        try JSONDecoder().decode([DisplayProfile].self, from: data)
    }

    static func save(_ profiles: [DisplayProfile], to url: URL = defaultURL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encode(profiles).write(to: url, options: .atomic)
        } catch {
            // Non-fatal.
        }
    }

    static func load(from url: URL = defaultURL) -> [DisplayProfile] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decode(data)) ?? []
    }
}
