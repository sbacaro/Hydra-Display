//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  VirtualDisplayBridge.swift
//  Hydra Display
//
//  Thin, defensive Swift layer over the private CGVirtualDisplay* classes.
//  Everything that can fail because the private API moved is funnelled
//  through here so the rest of the app never crashes on a future macOS.
//

import Foundation
import CoreGraphics

/// One advertised resolution for a virtual display.
struct VirtualDisplayMode: Hashable, Codable, Identifiable {
    var width: Int
    var height: Int
    var refreshRate: Double

    var id: String { "\(width)x\(height)@\(Int(refreshRate))" }

    /// The logical (point) size when this mode is shown HiDPI (2x).
    var hiDPIPointSize: (w: Int, h: Int) { (width / 2, height / 2) }

    var label: String { "\(width) × \(height)" }
}

/// Parameters used to spin up a brand-new virtual display.
struct VirtualDisplaySpec {
    var name: String
    var widthMillimeters: Double
    var heightMillimeters: Double
    var hiDPI: Bool
    var modes: [VirtualDisplayMode]

    /// The largest mode determines the framebuffer the display can ever use.
    var maxPixelsWide: Int { modes.map(\.width).max() ?? 1920 }
    var maxPixelsHigh: Int { modes.map(\.height).max() ?? 1080 }
}

/// Owns a live `CGVirtualDisplay`. The display exists for exactly as long as
/// this object is alive, so the app keeps a strong reference per display and
/// drops it to remove the display.
final class VirtualDisplayHandle: Identifiable {
    let id = UUID()
    let spec: VirtualDisplaySpec
    let cgDisplayID: CGDirectDisplayID

    /// Held only as `AnyObject` so nothing outside the bridge can poke the
    /// private object directly.
    private let backing: AnyObject

    fileprivate init(backing: AnyObject, displayID: CGDirectDisplayID, spec: VirtualDisplaySpec) {
        self.backing = backing
        self.cgDisplayID = displayID
        self.spec = spec
    }
}

enum VirtualDisplayError: LocalizedError {
    case privateAPIUnavailable
    case creationFailed
    case applySettingsFailed
    case invalidDisplayID

    var errorDescription: String? {
        switch self {
        case .privateAPIUnavailable:
            return "This version of macOS no longer exposes the private "
                + "CoreGraphics virtual-display API that Hydra Display relies on."
        case .creationFailed:
            return "macOS refused to create the virtual display."
        case .applySettingsFailed:
            return "The virtual display was created but its resolution settings were rejected."
        case .invalidDisplayID:
            return "The virtual display was created but never received a valid display ID."
        }
    }
}

/// Stateless factory. All access to the private classes lives here.
enum VirtualDisplayBridge {

    /// True when the private classes are present in the running CoreGraphics.
    static var isAvailable: Bool {
        NSClassFromString("CGVirtualDisplayDescriptor") != nil
            && NSClassFromString("CGVirtualDisplay") != nil
            && NSClassFromString("CGVirtualDisplaySettings") != nil
            && NSClassFromString("CGVirtualDisplayMode") != nil
    }

    /// Creates a live virtual display from `spec`. Throws rather than crashing
    /// if the private API is missing or rejects the request.
    static func create(_ spec: VirtualDisplaySpec) throws -> VirtualDisplayHandle {
        guard isAvailable else { throw VirtualDisplayError.privateAPIUnavailable }

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.queue = DispatchQueue.global(qos: .userInteractive)
        descriptor.name = spec.name
        // A stable-ish identity. Randomised serial keeps multiple displays distinct.
        descriptor.vendorID = 0x484C // "HL" – Hydra-Local
        descriptor.productID = 0x2026
        descriptor.serialNum = UInt32.random(in: 1...UInt32.max)
        descriptor.maxPixelsWide = UInt32(spec.maxPixelsWide)
        descriptor.maxPixelsHigh = UInt32(spec.maxPixelsHigh)
        descriptor.sizeInMillimeters = CGSize(width: spec.widthMillimeters,
                                              height: spec.heightMillimeters)
        // sRGB primaries.
        descriptor.redPrimary = CGPoint(x: 0.640, y: 0.330)
        descriptor.greenPrimary = CGPoint(x: 0.300, y: 0.600)
        descriptor.bluePrimary = CGPoint(x: 0.150, y: 0.060)
        descriptor.whitePoint = CGPoint(x: 0.3127, y: 0.3290)
        descriptor.terminationHandler = { _, _ in }

        let display = CGVirtualDisplay(descriptor: descriptor)

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = spec.hiDPI ? 1 : 0
        settings.modes = spec.modes.map {
            CGVirtualDisplayMode(width: UInt32($0.width),
                                 height: UInt32($0.height),
                                 refreshRate: $0.refreshRate)
        }

        guard display.apply(settings) else {
            throw VirtualDisplayError.applySettingsFailed
        }

        let displayID = display.displayID
        guard displayID != 0 else { throw VirtualDisplayError.invalidDisplayID }

        return VirtualDisplayHandle(backing: display,
                                    displayID: CGDirectDisplayID(displayID),
                                    spec: spec)
    }
}
