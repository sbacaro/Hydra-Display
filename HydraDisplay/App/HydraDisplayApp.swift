//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  HydraDisplayApp.swift
//  Hydra Display
//
//  Open-source, Liquid-Glass virtual-display manager for macOS 26.
//  https://github.com/sbacaro/Hydra-Display
//

import SwiftUI

@main
struct HydraDisplayApp: App {
    // Shared manager (also used by App Intents). Restore is internally skipped
    // while hosting unit tests so they never create displays.
    @State private var manager = DisplayManager.shared
    @State private var settings = AppSettings()
    @State private var updater = Updater()
    @State private var gamma = GammaController.shared
    @State private var pip = PiPManager.shared

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            ContentView()
                .environment(manager)
                .environment(settings)
                .environment(updater)
                .environment(gamma)
                .frame(minWidth: 760, minHeight: 520)
                .task {
                    Log.app.info("\(AppInfo.versionString, privacy: .public) launched")
                    if settings.autoCheckUpdates && !AppEnvironment.isUnitTesting {
                        await updater.check()
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {} // no "New" document
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
                CheckUpdatesMenuButton()
            }
            CommandGroup(replacing: .help) {
                Link("\(AppInfo.name) on GitHub", destination: AppInfo.repositoryURL)
                Link("Report an Issue", destination: AppInfo.issuesURL)
            }
        }

        // Custom About window (single instance), sized to its content.
        Window("About \(AppInfo.name)", id: "about") {
            AboutView()
                .environment(updater)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)

        // Floating, real-time Picture-in-Picture windows (ScreenCaptureKit).
        WindowGroup(id: "pip", for: CaptureSource.self) { $source in
            if let source {
                PiPContentView(source: source)
            }
        }
        .windowResizability(.contentSize)

        // Preferences window (⌘,).
        Settings {
            SettingsView(settings: settings)
                .environment(updater)
        }

        // Quick-glance controls in the menu bar.
        MenuBarExtra(AppInfo.name, systemImage: AppInfo.symbol) {
            MenuBarView()
                .environment(manager)
                .environment(updater)
                .environment(pip)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Opens the custom About window from the application menu.
private struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("About \(AppInfo.name)") { openWindow(id: "about") }
    }
}

/// "Check for Updates…" — opens the About window, which hosts the updater UI.
private struct CheckUpdatesMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Check for Updates…") {
            openWindow(id: "about")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
