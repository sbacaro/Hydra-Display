//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  ResolutionMenu.swift
//  Hydra Display
//
//  A drop-down that switches a display's active resolution live. Works for any
//  display (physical or virtual) via the public CoreGraphics mode API.
//

import SwiftUI

struct ResolutionMenu: View {
    @Environment(DisplayManager.self) private var manager
    let displayID: CGDirectDisplayID
    var compact = false

    var body: some View {
        Menu {
            let modes = manager.availableModes(for: displayID)
            let current = manager.currentMode(for: displayID)
            if modes.isEmpty {
                Text("No selectable resolutions")
            } else {
                ForEach(modes) { mode in
                    Button {
                        manager.setMode(mode, for: displayID)
                    } label: {
                        if current == mode {
                            Label(mode.menuLabel, systemImage: "checkmark")
                        } else {
                            Text(mode.menuLabel)
                        }
                    }
                }
            }
        } label: {
            if compact {
                Image(systemName: "slider.horizontal.3")
            } else {
                Label(manager.currentMode(for: displayID)?.label ?? "Resolution",
                      systemImage: "slider.horizontal.3")
                    .monospacedDigit()
            }
        }
        .menuIndicator(compact ? .hidden : .visible)
        .help("Change resolution")
    }
}
