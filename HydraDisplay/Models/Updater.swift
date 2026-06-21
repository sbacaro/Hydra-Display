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
import CryptoKit
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

    /// The published checksum manifest (`SHA256SUMS.txt`) used to verify downloads.
    var checksumsAsset: Asset? {
        assets.first { $0.name == "SHA256SUMS.txt" }
    }
}

enum UpdaterError: LocalizedError {
    case noAsset
    case extractionFailed(String)
    case appNotFound
    case installFailed(String)
    case cancelled
    case integrityUnavailable
    case integrityFailed(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .noAsset: return "The latest release has no downloadable app."
        case .extractionFailed(let m): return "Couldn't unpack the update: \(m)"
        case .appNotFound: return "The downloaded update didn't contain the app."
        case .installFailed(let m): return "Couldn't install the update: \(m)"
        case .cancelled: return "Update cancelled."
        case .integrityUnavailable:
            return "Couldn't verify the update — its published checksum is missing. "
                 + "Installation was cancelled for safety."
        case .integrityFailed:
            return "The update failed its integrity check and was not installed. "
                 + "The download may be corrupted or tampered with."
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
            let newer = Self.isNewer(release.version, than: AppInfo.version)
            phase = newer ? .available : .upToDate
            let verdict = newer ? "update available" : "up to date"
            Log.updater.info("Checked: latest \(release.version, privacy: .public), current \(AppInfo.version, privacy: .public) — \(verdict, privacy: .public)")
        } catch {
            Log.updater.error("Check failed: \(error.localizedDescription, privacy: .public)")
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
            // Fetch the published checksum first; if it's missing we refuse to install.
            let expected = try await Self.expectedChecksum(for: asset, in: release)
            let newApp = try await Self.downloadVerifyExtract(asset: asset,
                                                              expectedSHA256: expected)
            Log.updater.info("Download verified (SHA-256 OK); installing \(release.version, privacy: .public)")
            phase = .installing
            try installPrivileged(replacing: Bundle.main.bundleURL, with: newApp)
            relaunch(Bundle.main.bundleURL)
        } catch {
            Log.updater.error("Update failed: \(error.localizedDescription, privacy: .public)")
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

    // MARK: Integrity

    /// Downloads the release's `SHA256SUMS.txt` and returns the expected hash for
    /// the given asset. Throws `integrityUnavailable` if no usable checksum exists.
    private nonisolated static func expectedChecksum(
        for asset: GitHubRelease.Asset, in release: GitHubRelease) async throws -> String {
        guard let sums = release.checksumsAsset else { throw UpdaterError.integrityUnavailable }
        var request = URLRequest(url: sums.browserDownloadURL)
        request.setValue("HydraDisplay", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let text = String(decoding: data, as: UTF8.self)
        guard let hash = parseChecksum(text, for: asset.name) else {
            throw UpdaterError.integrityUnavailable
        }
        return hash
    }

    /// Parses a `shasum`-style manifest (`<hex>␠␠<filename>`) for one file's hash.
    nonisolated static func parseChecksum(_ manifest: String, for filename: String) -> String? {
        for line in manifest.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 2, let hex = fields.first else { continue }
            // Binary mode prefixes the name with "*"; strip it before comparing.
            var name = String(fields[fields.count - 1])
            if name.hasPrefix("*") { name.removeFirst() }
            if name == filename { return String(hex).lowercased() }
        }
        return nil
    }

    nonisolated static func sha256(ofFileAt url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Download + verify + extract (off the main actor, no visible terminal)

    private nonisolated static func downloadVerifyExtract(
        asset: GitHubRelease.Asset, expectedSHA256: String) async throws -> URL {
        let (tmp, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)

        let fm = FileManager.default
        let work = fm.temporaryDirectory
            .appendingPathComponent("HydraUpdate-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let zip = work.appendingPathComponent("update.zip")
        try fm.moveItem(at: tmp, to: zip)

        // Verify integrity BEFORE unpacking or touching the installed app.
        let actual = try sha256(ofFileAt: zip)
        guard actual == expectedSHA256.lowercased() else {
            try? fm.removeItem(at: work)
            throw UpdaterError.integrityFailed(expected: expectedSHA256, actual: actual)
        }

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
