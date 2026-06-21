//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  PiPStreamController.swift
//  Hydra Display
//
//  Live Picture-in-Picture capture. Streams a display or a single window with
//  ScreenCaptureKit and pushes each frame's IOSurface straight into a CALayer
//  for GPU-cheap, real-time rendering.
//
//  Capturing requires the Screen Recording permission (prompted on first use).
//

import AppKit
import CoreMedia
import CoreVideo
import IOSurface
import ScreenCaptureKit

/// What a PIP window is showing. Codable/Hashable so it can drive a WindowGroup.
struct CaptureSource: Hashable, Codable {
    enum Kind: String, Codable { case display, window }
    var kind: Kind
    var rawID: UInt32
    var title: String

    static func display(_ id: CGDirectDisplayID, title: String) -> CaptureSource {
        CaptureSource(kind: .display, rawID: id, title: title)
    }
    static func window(_ id: CGWindowID, title: String) -> CaptureSource {
        CaptureSource(kind: .window, rawID: id, title: title)
    }
}

/// Passes a frame surface across the capture queue → main actor boundary.
private struct SurfaceBox: @unchecked Sendable {
    let surface: IOSurfaceRef
}

@MainActor
@Observable
final class PiPStreamController {

    /// The layer the PIP view displays. Frames are written straight into it.
    let previewLayer: CALayer
    var errorText: String?
    private(set) var isRunning = false

    private var stream: SCStream?
    private let output = FrameOutput()
    private let frameQueue = DispatchQueue(label: "app.hydradisplay.pip.frames",
                                           qos: .userInteractive)

    init() {
        let layer = CALayer()
        layer.contentsGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
        previewLayer = layer
        output.onSurface = { [weak self] box in
            // Already on the main actor (FrameOutput hops here).
            self?.previewLayer.contents = box.surface
        }
    }

    func start(_ source: CaptureSource) async {
        await stop()
        do {
            let content = try await SCShareableContent.current
            let config = SCStreamConfiguration()
            config.showsCursor = false   // don't draw the pointer into the PIP feed
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.queueDepth = 5
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

            let filter: SCContentFilter
            switch source.kind {
            case .display:
                guard let display = content.displays.first(where: { $0.displayID == source.rawID })
                else { errorText = "That display is no longer available."; return }
                filter = SCContentFilter(display: display, excludingWindows: [])
                config.width = max(CGDisplayPixelsWide(source.rawID), 2)
                config.height = max(CGDisplayPixelsHigh(source.rawID), 2)
            case .window:
                guard let window = content.windows.first(where: { $0.windowID == source.rawID })
                else { errorText = "That window is no longer available."; return }
                filter = SCContentFilter(desktopIndependentWindow: window)
                config.width = max(Int(window.frame.width) * 2, 2)
                config.height = max(Int(window.frame.height) * 2, 2)
            }

            let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
            try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: frameQueue)
            try await newStream.startCapture()
            stream = newStream
            isRunning = true
            errorText = nil
        } catch {
            Log.capture.error("PIP capture failed: \(error.localizedDescription, privacy: .public)")
            errorText = error.localizedDescription
            isRunning = false
        }
    }

    func stop() async {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        isRunning = false
    }
}

/// SCStream output that forwards each frame's IOSurface to the main actor.
private final class FrameOutput: NSObject, SCStreamOutput, @unchecked Sendable {

    /// Called on the main actor for every frame.
    var onSurface: (@MainActor (SurfaceBox) -> Void)?

    nonisolated func stream(_ stream: SCStream,
                            didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                            of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        else { return }

        let box = SurfaceBox(surface: surface)
        Task { @MainActor [weak self] in
            self?.onSurface?(box)
        }
    }
}
