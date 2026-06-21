//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  ResolutionPresets.swift
//  Hydra Display
//
//  Curated resolution catalogue used by the "create display" sheet and the
//  per-display presets editor. Virtual displays advertise *pixel* modes;
//  when HiDPI is on, macOS renders them at half the point size (Retina 2x).
//

import Foundation

enum ResolutionPresets {

    struct Preset: Identifiable, Hashable {
        let name: String
        let width: Int
        let height: Int
        var id: String { "\(width)x\(height)" }

        var aspect: String {
            let g = gcd(width, height)
            return "\(width / g):\(height / g)"
        }

        func mode(refreshRate: Double = 60) -> VirtualDisplayMode {
            VirtualDisplayMode(width: width, height: height, refreshRate: refreshRate)
        }
    }

    /// Groups shown in the picker.
    static let groups: [(title: String, presets: [Preset])] = [
        ("16:9", [
            Preset(name: "HD",          width: 1280, height: 720),
            Preset(name: "FHD",         width: 1920, height: 1080),
            Preset(name: "QHD",         width: 2560, height: 1440),
            Preset(name: "4K UHD",      width: 3840, height: 2160),
            Preset(name: "5K",          width: 5120, height: 2880),
        ]),
        ("16:10", [
            Preset(name: "WXGA+",       width: 1680, height: 1050),
            Preset(name: "WQXGA",       width: 2560, height: 1600),
            Preset(name: "MacBook 14\"", width: 3024, height: 1964),
            Preset(name: "MacBook 16\"", width: 3456, height: 2234),
        ]),
        ("Ultrawide", [
            Preset(name: "UW-FHD",      width: 2560, height: 1080),
            Preset(name: "UW-QHD",      width: 3440, height: 1440),
            Preset(name: "5K2K",        width: 5120, height: 2160),
        ]),
        ("Portrait / Tablet", [
            Preset(name: "iPad 11\"",   width: 1668, height: 2388),
            Preset(name: "Portrait FHD", width: 1080, height: 1920),
        ]),
    ]

    static let all: [Preset] = groups.flatMap(\.presets)

    /// Sensible default set of modes a freshly-created display advertises.
    static let defaultModes: [VirtualDisplayMode] = [
        Preset(name: "FHD",    width: 1920, height: 1080).mode(),
        Preset(name: "QHD",    width: 2560, height: 1440).mode(),
        Preset(name: "4K UHD", width: 3840, height: 2160).mode(),
    ]

    /// Rough physical size (mm) for a given diagonal-less preset, assuming
    /// ~109 ppi for non-HiDPI and ~218 ppi for HiDPI panels.
    static func millimeters(for width: Int, height: Int, hiDPI: Bool) -> (w: Double, h: Double) {
        let ppi = hiDPI ? 218.0 : 109.0
        let mmPerInch = 25.4
        return (Double(width) / ppi * mmPerInch, Double(height) / ppi * mmPerInch)
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    var a = a, b = b
    while b != 0 { (a, b) = (b, a % b) }
    return max(a, 1)
}
