//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  HydraDisplayIntents.swift
//  Hydra Display
//
//  App Intents exposing Hydra to the Shortcuts app and Spotlight. They operate
//  on the shared DisplayManager so they share state with the running app.
//

import AppIntents

// MARK: - Resolution choice

enum QuickResolution: String, AppEnum {
    case retina4K
    case retina1440p
    case fullHD

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Resolution"

    static let caseDisplayRepresentations: [QuickResolution: DisplayRepresentation] = [
        .retina4K: "4K Retina",
        .retina1440p: "1440p Retina",
        .fullHD: "1080p",
    ]

    var displayName: String {
        switch self {
        case .retina4K: return "4K Retina"
        case .retina1440p: return "1440p Retina"
        case .fullHD: return "1080p"
        }
    }

    var pixels: (w: Int, h: Int) {
        switch self {
        case .retina4K: return (3840, 2160)
        case .retina1440p: return (2560, 1440)
        case .fullHD: return (1920, 1080)
        }
    }

    var hiDPI: Bool { self != .fullHD }

    var spec: VirtualDisplaySpec {
        let mm = ResolutionPresets.millimeters(for: pixels.w, height: pixels.h, hiDPI: hiDPI)
        return VirtualDisplaySpec(
            name: displayName,
            widthMillimeters: mm.w, heightMillimeters: mm.h,
            hiDPI: hiDPI,
            modes: [VirtualDisplayMode(width: pixels.w, height: pixels.h, refreshRate: 60)])
    }
}

// MARK: - Create

struct CreateVirtualDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Virtual Display"
    static let description = IntentDescription("Creates a new virtual display.")
    static let openAppWhenRun = true   // keep the app alive to hold the display

    @Parameter(title: "Resolution", default: .retina4K)
    var resolution: QuickResolution

    static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$resolution) virtual display")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard DisplayManager.shared.isVirtualDisplaySupported else {
            return .result(dialog: "Virtual displays aren't available on this macOS build.")
        }
        if DisplayManager.shared.createVirtualDisplay(resolution.spec) != nil {
            return .result(dialog: "Created a \(resolution.displayName) virtual display.")
        }
        let message = DisplayManager.shared.lastError ?? "Couldn't create the virtual display."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Remove all

struct RemoveAllVirtualDisplaysIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove All Virtual Displays"
    static let description = IntentDescription("Removes every virtual display Hydra created.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = DisplayManager.shared.virtualHandles.count
        DisplayManager.shared.removeAll()
        let noun = count == 1 ? "virtual display" : "virtual displays"
        return .result(dialog: "Removed \(count) \(noun).")
    }
}

// MARK: - Spotlight / Shortcuts phrases

struct HydraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateVirtualDisplayIntent(),
            phrases: [
                "Create a virtual display with \(.applicationName)",
                "New virtual display in \(.applicationName)",
            ],
            shortTitle: "New Virtual Display",
            systemImageName: "plus.rectangle.on.rectangle")
        AppShortcut(
            intent: RemoveAllVirtualDisplaysIntent(),
            phrases: [
                "Remove all virtual displays with \(.applicationName)",
            ],
            shortTitle: "Remove Displays",
            systemImageName: "trash")
    }
}
