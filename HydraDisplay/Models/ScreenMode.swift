//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  ScreenMode.swift
//  Hydra Display
//
//  A UI-facing snapshot of a `CGDisplayMode` (the *active* resolution a display
//  is currently running, as opposed to the modes a virtual display advertises).
//  Kept as a Sendable value type so it can flow through SwiftUI; the underlying
//  CGDisplayMode is re-resolved by the manager when a mode is applied.
//

import Foundation
import CoreGraphics

struct ScreenMode: Identifiable, Hashable, Sendable {
    /// Logical (point) size — what the user perceives as the resolution.
    let width: Int
    let height: Int
    /// Backing pixel size. For Retina/HiDPI modes this is larger than the point size.
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double

    var isHiDPI: Bool { pixelWidth > width || pixelHeight > height }

    var id: String { "\(pixelWidth)x\(pixelHeight)@\(Int(refreshRate.rounded()))" }

    /// "1512 × 982" — the point size users recognise.
    var label: String { "\(width) × \(height)" }

    /// A disambiguated row label: point size, a HiDPI hint, and a refresh rate
    /// when it isn't the usual 60 Hz.
    var menuLabel: String {
        var text = label
        if isHiDPI { text += " · HiDPI" }
        let hz = Int(refreshRate.rounded())
        if hz != 0 && hz != 60 { text += " · \(hz) Hz" }
        return text
    }
}

extension ScreenMode {
    init(_ mode: CGDisplayMode) {
        self.init(width: mode.width,
                  height: mode.height,
                  pixelWidth: mode.pixelWidth,
                  pixelHeight: mode.pixelHeight,
                  refreshRate: mode.refreshRate)
    }

    /// Whether this value describes the same `CGDisplayMode`.
    func matches(_ mode: CGDisplayMode) -> Bool {
        mode.pixelWidth == pixelWidth
            && mode.pixelHeight == pixelHeight
            && mode.width == width
            && mode.height == height
            && abs(mode.refreshRate - refreshRate) < 0.5
    }
}
