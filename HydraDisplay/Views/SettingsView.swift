//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  SettingsView.swift
//  Hydra Display
//
//  Preferences window (⌘,). Standard macOS Form layout.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(Updater.self) private var updater

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            updates
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(width: 480, height: 300)
    }

    private var general: some View {
        Form {
            Section {
                Toggle(isOn: $settings.launchAtLogin) {
                    Text("Open at Login")
                    Text("Start Hydra Display automatically when you sign in.")
                }
                Toggle(isOn: $settings.restoreOnLaunch) {
                    Text("Restore Virtual Displays on Launch")
                    Text("Recreate the virtual displays you had when the app last quit.")
                }
                Toggle(isOn: $settings.enableGlobalHotkeys) {
                    Text("Global Keyboard Shortcuts")
                    Text("⌃⌥⌘N — new 4K Retina display   ·   ⌃⌥⌘R — remove all")
                }
            }

            if let error = settings.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updates: some View {
        Form {
            Section {
                Toggle(isOn: $settings.autoCheckUpdates) {
                    Text("Check for Updates Automatically")
                    Text("Look for a newer release on GitHub each time the app launches.")
                }
            }
            Section {
                LabeledContent("Current version", value: AppInfo.versionString)
                HStack {
                    updateStatus
                    Spacer()
                    switch updater.phase {
                    case .available:
                        Button("Update Now") { Task { await updater.update() } }
                            .buttonStyle(.borderedProminent)
                    default:
                        Button("Check Now") { Task { await updater.check() } }
                            .disabled(updater.isBusy)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updateStatus: some View {
        Group {
            switch updater.phase {
            case .idle:
                Text("Not checked yet").foregroundStyle(.secondary)
            case .checking:
                Label("Checking…", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.secondary)
            case .upToDate:
                Label("Up to date", systemImage: "checkmark.circle").foregroundStyle(.green)
            case .available:
                Label("Version \(updater.availableVersion ?? "") available", systemImage: "arrow.down.circle")
                    .foregroundStyle(.tint)
            case .downloading:
                Label("Downloading…", systemImage: "arrow.down").foregroundStyle(.secondary)
            case .installing:
                Label("Installing…", systemImage: "gearshape").foregroundStyle(.secondary)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).lineLimit(2)
            }
        }
        .font(.callout)
    }
}
