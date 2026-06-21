//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  Diagnostics.swift
//  Hydra Display
//
//  Builds a plain-text diagnostics report — app + system info, the current
//  display topology with color adjustments, and recent unified-log entries for
//  the app — so users can attach it when reporting an issue. No data leaves the
//  machine; the report is only written where the user chooses to save it.
//

import Foundation
import OSLog

enum Diagnostics {

    /// A filename like `HydraDisplay-Diagnostics-2026-06-21-1432.txt`.
    static var suggestedFilename: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmm"
        return "HydraDisplay-Diagnostics-\(df.string(from: Date())).txt"
    }

    @MainActor
    static func generate() -> String {
        var out = ""
        func line(_ s: String = "") { out += s + "\n" }

        line("Hydra Display — Diagnostics")
        line("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        line(String(repeating: "—", count: 52))
        line()

        line("App")
        line("  \(AppInfo.versionString)")
        line("  Bundle ID:  \(AppInfo.bundleIdentifier)")
        line("  Location:   \(Bundle.main.bundleURL.path)")
        line()

        let pi = ProcessInfo.processInfo
        line("System")
        line("  macOS:      \(pi.operatingSystemVersionString)")
        line("  Model:      \(sysctlString("hw.model"))")
        line("  Arch:       \(currentArch())")
        line("  Memory:     \(ByteCountFormatter.string(fromByteCount: Int64(pi.physicalMemory), countStyle: .memory))")
        line("  Virtual-display API: \(DisplayManager.shared.isVirtualDisplaySupported ? "available" : "unavailable")")
        line()

        let displays = DisplayManager.shared.allDisplays
        line("Displays (\(displays.count))")
        for d in displays {
            var flags: [String] = []
            if d.isMain { flags.append("main") }
            if d.isVirtualHydra { flags.append("virtual") }
            if d.isMirrored { flags.append("mirrored") }
            let suffix = flags.isEmpty ? "" : " — \(flags.joined(separator: ", "))"
            line("  • \(d.name) [#\(d.id)]  \(d.resolutionLabel)\(suffix)")
            let adj = GammaController.shared.adjustment(for: d.id)
            if !adj.isNeutral {
                line("      color: brightness \(Int((adj.brightness * 100).rounded()))%, "
                     + "temperature \(String(format: "%+.2f", adj.temperature))")
            }
        }
        line()

        line("Open PIP windows (\(PiPManager.shared.sessions.count))")
        for s in PiPManager.shared.sessions {
            line("  • \(s.title) — opacity \(Int((s.opacity * 100).rounded()))%"
                 + (s.clickThrough ? ", click-through" : ""))
        }
        line()

        line("Recent log (last hour, newest last)")
        for entry in recentLogLines() { line("  \(entry)") }

        return out
    }

    // MARK: - Unified log

    private static func recentLogLines(limit: Int = 400) -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let start = store.position(date: Date().addingTimeInterval(-3600))
            let predicate = NSPredicate(format: "subsystem == %@", AppInfo.bundleIdentifier)
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            var lines: [String] = []
            for entry in try store.getEntries(at: start, matching: predicate) {
                guard let log = entry as? OSLogEntryLog else { continue }
                lines.append("[\(df.string(from: log.date))] (\(log.category)) \(log.composedMessage)")
            }
            if lines.count > limit { lines = Array(lines.suffix(limit)) }
            return lines.isEmpty ? ["(no entries yet)"] : lines
        } catch {
            return ["(log unavailable: \(error.localizedDescription))"]
        }
    }

    // MARK: - Hardware probes

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "—" }
        var buffer = [UInt8](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        if let nul = buffer.firstIndex(of: 0) { buffer.removeSubrange(nul...) }
        return String(decoding: buffer, as: UTF8.self)
    }

    private static func currentArch() -> String {
        #if arch(arm64)
        return "arm64 (Apple silicon)"
        #elseif arch(x86_64)
        return "x86_64 (Intel)"
        #else
        return "unknown"
        #endif
    }
}
