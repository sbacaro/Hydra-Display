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
    // One shared manager for the main window and the menu-bar extra.
    @State private var manager = DisplayManager()

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            ContentView()
                .environment(manager)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {} // no "New" document
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
            CommandGroup(replacing: .help) {
                Link("\(AppInfo.name) on GitHub", destination: AppInfo.repositoryURL)
                Link("Report an Issue", destination: AppInfo.issuesURL)
            }
        }

        // Custom About window (single instance), sized to its content.
        Window("About \(AppInfo.name)", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)

        // Quick-glance controls in the menu bar.
        MenuBarExtra(AppInfo.name, systemImage: AppInfo.symbol) {
            MenuBarView()
                .environment(manager)
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
