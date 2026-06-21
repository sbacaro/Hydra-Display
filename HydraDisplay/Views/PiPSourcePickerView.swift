//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  PiPSourcePickerView.swift
//  Hydra Display
//
//  Lets the user pick a display or an app window to open as a floating,
//  always-on-top, live Picture-in-Picture window.
//

import SwiftUI
import ScreenCaptureKit

struct PiPSourcePickerView: View {
    @Environment(DisplayManager.self) private var manager
    @Environment(\.openWindow) private var openWindow

    @State private var windows: [WindowItem] = []
    @State private var loadError: String?
    @State private var isLoading = true

    struct WindowItem: Identifiable, Hashable {
        let id: CGWindowID
        let title: String
        let app: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                intro
                displaysSection
                windowsSection
            }
            .padding(Theme.Space.xl)
        }
        .navigationTitle("Picture in Picture")
        .scrollContentBackground(.hidden)
        .task { await loadWindows() }
    }

    private var intro: some View {
        Text("Open any screen or window as a floating, always-on-top preview that "
             + "updates in real time — even over full-screen apps.")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var displaysSection: some View {
        SectionCard("Displays", systemImage: "display") {
            ForEach(Array(manager.allDisplays.enumerated()), id: \.element.id) { index, display in
                if index > 0 { Divider() }
                sourceRow(icon: display.isVirtualHydra ? "display" : "desktopcomputer",
                          title: display.name,
                          subtitle: display.resolutionLabel) {
                    openWindow(id: "pip",
                               value: CaptureSource.display(display.id, title: display.name))
                }
            }
        }
    }

    private var windowsSection: some View {
        SectionCard("Windows", systemImage: "macwindow") {
            if isLoading {
                HStack(spacing: Theme.Space.s) {
                    ProgressView().controlSize(.small)
                    Text("Looking for windows…").foregroundStyle(.secondary)
                }
                .font(.callout)
            } else if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
            } else if windows.isEmpty {
                Text("No capturable windows found.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                    if index > 0 { Divider() }
                    sourceRow(icon: "macwindow",
                              title: window.title,
                              subtitle: window.app) {
                        openWindow(id: "pip",
                                   value: CaptureSource.window(window.id, title: window.title))
                    }
                }
            }
        }
    }

    private func sourceRow(icon: String, title: String, subtitle: String,
                           open: @escaping () -> Void) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button("Open PIP", action: open)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    /// System/agent windows that should never be offered for PIP.
    private static let blockedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.WindowManager",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.Spotlight",
        "com.apple.systemuiserver",
        "com.apple.wallpaper.agent",
        "com.apple.screencaptureui",
        "com.apple.loginwindow",
    ]

    private func loadWindows() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Excludes the desktop/wallpaper "backstop" windows and off-screen windows.
            let content = try await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true)
            let myPID = ProcessInfo.processInfo.processIdentifier

            windows = content.windows
                .filter { window in
                    guard let app = window.owningApplication else { return false }
                    return window.isOnScreen
                        && window.windowLayer == 0              // normal app windows only
                        && (window.title?.isEmpty == false)
                        && window.frame.width >= 120 && window.frame.height >= 80
                        && app.processID != myPID
                        && app.bundleIdentifier != AppInfo.bundleIdentifier
                        && !Self.blockedBundleIDs.contains(app.bundleIdentifier)
                }
                .compactMap { window -> WindowItem? in
                    guard let title = window.title, let app = window.owningApplication
                    else { return nil }
                    return WindowItem(id: window.windowID, title: title,
                                      app: app.applicationName)
                }
                .sorted { ($0.app.lowercased(), $0.title.lowercased())
                        < ($1.app.lowercased(), $1.title.lowercased()) }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}
