//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  PiPSession.swift
//  Hydra Display
//
//  Per-window state for an open Picture-in-Picture window (opacity and
//  click-through), plus a small registry so the menu bar can list every open
//  PIP and toggle them — the reliable way back out of click-through, which by
//  definition makes the window itself ignore the mouse.
//

import AppKit
import Observation

@MainActor
@Observable
final class PiPSession: Identifiable {
    let id = UUID()
    let title: String
    private(set) var opacity: Double = 1.0
    private(set) var clickThrough: Bool = false
    weak var window: NSWindow?

    static let minOpacity = 0.2

    init(title: String, window: NSWindow) {
        self.title = title
        self.window = window
    }

    func setOpacity(_ value: Double) {
        opacity = min(max(value, Self.minOpacity), 1.0)
        window?.alphaValue = opacity
    }

    func setClickThrough(_ on: Bool) {
        clickThrough = on
        window?.ignoresMouseEvents = on
    }

    func close() {
        window?.close()
    }
}

/// Tracks every open PIP window so other surfaces (the menu bar) can control them.
@MainActor
@Observable
final class PiPManager {
    static let shared = PiPManager()

    private(set) var sessions: [PiPSession] = []

    func register(_ session: PiPSession) {
        sessions.append(session)
    }

    func unregister(_ session: PiPSession) {
        sessions.removeAll { $0.id == session.id }
    }
}
