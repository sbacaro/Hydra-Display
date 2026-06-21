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
    private let streamDelegate = StreamDelegate()
    private let frameQueue = DispatchQueue(label: "app.hydradisplay.pip.frames",
                                           qos: .userInteractive)

    /// What we're currently capturing, so we can re-bind a window that changed ID.
    private var currentSource: CaptureSource?
    /// Owning-app PID of a window source — used to find its new window after it
    /// enters full screen (which destroys the old window and makes a new one).
    private var sourcePID: pid_t?
    /// True while we're tearing a stream down on purpose, so the delegate's
    /// stop callback doesn't trigger an auto-rebind.
    private var isStopping = false
    private var lastRebind = Date.distantPast

    init() {
        let layer = CALayer()
        layer.contentsGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
        previewLayer = layer
        output.onSurface = { [weak self] box in
            // Already on the main actor (FrameOutput hops here).
            self?.previewLayer.contents = box.surface
        }
        streamDelegate.onStop = { [weak self] _ in self?.handleStreamStopped() }
    }

    func start(_ source: CaptureSource) async {
        await stop()
        currentSource = source
        sourcePID = nil
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
                let size = Self.cappedSize(CGDisplayPixelsWide(source.rawID),
                                           CGDisplayPixelsHigh(source.rawID))
                config.width = size.w
                config.height = size.h
            case .window:
                guard let window = content.windows.first(where: { $0.windowID == source.rawID })
                else { errorText = "That window is no longer available."; return }
                sourcePID = window.owningApplication?.processID
                filter = SCContentFilter(desktopIndependentWindow: window)
                // Capture at ~2× the window's point size for crispness, but cap the
                // result — a full-screen video on a Retina display would otherwise ask
                // for a 5K+ 60 fps BGRA stream and saturate the GPU.
                let size = Self.cappedSize(Int(window.frame.width) * 2,
                                           Int(window.frame.height) * 2)
                config.width = size.w
                config.height = size.h
            }

            let newStream = SCStream(filter: filter, configuration: config,
                                     delegate: streamDelegate)
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

    /// Clamps a capture size so its longest side never exceeds `maxDimension`,
    /// keeping aspect ratio. Prevents runaway GPU/memory load on huge windows.
    nonisolated static func cappedSize(_ width: Int, _ height: Int,
                                       maxDimension: Int = 2560) -> (w: Int, h: Int) {
        let w = Swift.max(width, 2)
        let h = Swift.max(height, 2)
        let longest = Swift.max(w, h)
        guard longest > maxDimension else { return (w, h) }
        let factor = Double(maxDimension) / Double(longest)
        return (Swift.max(Int(Double(w) * factor), 2),
                Swift.max(Int(Double(h) * factor), 2))
    }

    func stop() async {
        isStopping = true
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        isRunning = false
        isStopping = false
    }

    // MARK: - Auto re-bind (window full-screen toggling changes its ID)

    /// The stream stopped unexpectedly. For a window source this usually means it
    /// entered/left full screen and got a new window ID — try to re-attach.
    private func handleStreamStopped() {
        guard !isStopping, currentSource?.kind == .window, let pid = sourcePID else { return }
        // Throttle so a genuinely-gone window can't cause a tight rebind loop.
        guard Date().timeIntervalSince(lastRebind) > 1.0 else { return }
        lastRebind = Date()
        Task { @MainActor [weak self] in await self?.rebindWindow(ownerPID: pid) }
    }

    private func rebindWindow(ownerPID: pid_t) async {
        guard let content = try? await SCShareableContent.current else { return }
        // The same app's largest normal window — a full-screen video is the biggest.
        let candidate = content.windows
            .filter { $0.owningApplication?.processID == ownerPID && $0.windowLayer == 0 }
            .max { ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height) }
        guard let candidate, var source = currentSource else { return }
        Log.capture.info("Re-binding PIP window after it changed ID")
        source.rawID = candidate.windowID
        await start(source)
    }
}

/// Catches unexpected stream stops (e.g. the captured window disappearing) and
/// hops to the main actor so the controller can react.
private final class StreamDelegate: NSObject, SCStreamDelegate, @unchecked Sendable {
    var onStop: (@MainActor (Error) -> Void)?

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in self?.onStop?(error) }
    }
}

/// SCStream output that forwards each frame's IOSurface to the main actor.
///
/// Frames are *coalesced*: if the main actor hasn't drained the previous frame
/// yet, newer frames simply replace it. This keeps at most one main-actor task
/// in flight, so a burst of frames can never pile up unbounded.
private final class FrameOutput: NSObject, SCStreamOutput, @unchecked Sendable {

    /// Called on the main actor with the most recent frame.
    var onSurface: (@MainActor (SurfaceBox) -> Void)?

    private let lock = NSLock()
    private var latest: SurfaceBox?
    private var scheduled = false

    nonisolated func stream(_ stream: SCStream,
                            didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                            of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        else { return }

        lock.lock()
        latest = SurfaceBox(surface: surface)
        let needsSchedule = !scheduled
        if needsSchedule { scheduled = true }
        lock.unlock()

        guard needsSchedule else { return }
        Task { @MainActor [weak self] in self?.drain() }
    }

    @MainActor private func drain() {
        lock.lock()
        let box = latest
        latest = nil
        scheduled = false
        lock.unlock()
        if let box { onSurface?(box) }
    }
}
