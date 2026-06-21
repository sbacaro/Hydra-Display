//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  Updater.swift
//  Hydra Display
//
//  In-app auto-updater (no Sparkle). It reads the latest GitHub Release,
//  downloads the .app.zip, and installs it over the running bundle.
//
//  The download and unzip run via `Process` (no visible terminal). The final
//  swap needs privileges, so it runs through AppleScript
//  `do shell script … with administrator privileges`, which shows the standard
//  macOS authentication dialog and runs as root — the user never sees a shell.
//

import Foundation
import AppKit
import Observation

// MARK: - GitHub release model

struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let htmlURL: String
    let body: String?
    let assets: [Asset]

    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadURL: URL
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case assets
    }

    /// Version number without a leading "v", e.g. "0.2.0".
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    /// The preferred downloadable asset (the zipped .app).
    var appZipAsset: Asset? {
        assets.first { $0.name.hasSuffix(".app.zip") }
            ?? assets.first { $0.name.hasSuffix(".zip") }
    }
}

enum UpdaterError: LocalizedError {
    case noAsset
    case extractionFailed(String)
    case appNotFound
    case installFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noAsset: return "The latest release has no downloadable app."
        case .extractionFailed(let m): return "Couldn't unpack the update: \(m)"
        case .appNotFound: return "The downloaded update didn't contain the app."
        case .installFailed(let m): return "Couldn't install the update: \(m)"
        case .cancelled: return "Update cancelled."
        }
    }
}

// MARK: - Updater

@Observable
@MainActor
final class Updater {

    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available
        case downloading
        case installing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var latest: GitHubRelease?

    private static let releasesAPI = URL(
        string: "https://api.github.com/repos/sbacaro/Hydra-Display/releases/latest")!

    var availableVersion: String? { latest?.version }

    var isBusy: Bool {
        switch phase {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    // MARK: Check

    func check() async {
        if isBusy { return }
        phase = .checking
        do {
            var request = URLRequest(url: Self.releasesAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("HydraDisplay", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latest = release
            phase = Self.isNewer(release.version, than: AppInfo.version) ? .available : .upToDate
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Update (download → install → relaunch)

    func update() async {
        guard let release = latest, let asset = release.appZipAsset else {
            phase = .failed(UpdaterError.noAsset.localizedDescription)
            return
        }
        phase = .downloading
        do {
            let newApp = try await Self.downloadAndExtract(from: asset.browserDownloadURL)
            phase = .installing
            try installPrivileged(replacing: Bundle.main.bundleURL, with: newApp)
            relaunch(Bundle.main.bundleURL)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Version compare

    nonisolated static func isNewer(_ remote: String, than local: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(whereSeparator: { $0 == "." || $0 == "-" }).map { Int($0) ?? 0 }
        }
        let r = parts(remote), l = parts(local)
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    // MARK: Download + extract (off the main actor, no visible terminal)

    private nonisolated static func downloadAndExtract(from url: URL) async throws -> URL {
        let (tmp, _) = try await URLSession.shared.download(from: url)

        let fm = FileManager.default
        let work = fm.temporaryDirectory
            .appendingPathComponent("HydraUpdate-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let zip = work.appendingPathComponent("update.zip")
        try fm.moveItem(at: tmp, to: zip)

        let extracted = work.appendingPathComponent("extracted", isDirectory: true)
        try runTool("/usr/bin/ditto", ["-x", "-k", zip.path, extracted.path])

        let app = try fm.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "app" }
        guard let app else { throw UpdaterError.appNotFound }
        return app
    }

    private nonisolated static func runTool(_ launchPath: String, _ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? "exit \(process.terminationStatus)"
            throw UpdaterError.extractionFailed(msg)
        }
    }

    // MARK: Privileged install (shows the macOS password dialog, no terminal)

    private func installPrivileged(replacing dest: URL, with newApp: URL) throws {
        let d = Self.shellQuote(dest.path)
        let n = Self.shellQuote(newApp.path)
        let command =
            "/bin/rm -rf \(d) && " +
            "/usr/bin/ditto \(n) \(d) && " +
            "/usr/bin/xattr -dr com.apple.quarantine \(d)"
        try Self.runWithAdminPrivileges(command)
    }

    /// Runs a shell command as root via AppleScript. macOS shows its native
    /// authentication dialog; there is no visible terminal.
    private static func runWithAdminPrivileges(_ command: String) throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -128 { throw UpdaterError.cancelled }       // user cancelled auth
            let msg = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "\(errorInfo)"
            throw UpdaterError.installFailed(msg)
        }
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: Relaunch

    private func relaunch(_ app: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", app.path]
        try? process.run()
        // Give `open` a moment to spawn the fresh instance, then quit this one.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            NSApp.terminate(nil)
        }
    }
}
