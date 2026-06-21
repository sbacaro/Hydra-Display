//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  PiPViews.swift
//  Hydra Display
//
//  The floating PIP window content and the AppKit glue that renders the live
//  capture layer and makes the window float above everything.
//

import SwiftUI

// MARK: - Layer host

/// Hosts a CALayer and keeps it sized to the view.
private final class LayerHostView: NSView {
    private let content: CALayer
    init(content: CALayer) {
        self.content = content
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(content)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        content.frame = bounds
    }
}

struct PreviewLayerView: NSViewRepresentable {
    let layer: CALayer
    func makeNSView(context: Context) -> NSView { LayerHostView(content: layer) }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Window configuration

/// Calls back with the hosting NSWindow once the view is in a window.
private final class WindowResolverView: NSView {
    var onResolve: ((NSWindow) -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { onResolve?(window) }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = WindowResolverView()
        view.onResolve = onResolve
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - PIP content

struct PiPContentView: View {
    let source: CaptureSource
    @State private var controller = PiPStreamController()

    var body: some View {
        ZStack {
            Color.black
            PreviewLayerView(layer: controller.previewLayer)
            if let error = controller.errorText {
                ContentUnavailableView("Can't capture this source",
                                       systemImage: "rectangle.slash",
                                       description: Text(error))
                    .foregroundStyle(.white)
            } else if !controller.isRunning {
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .frame(minWidth: 240, minHeight: 150)
        .background(WindowAccessor { window in
            window.level = .floating
            window.collectionBehavior.insert(.canJoinAllSpaces)
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.title = source.title
        })
        .task(id: source) { await controller.start(source) }
        .onDisappear { Task { @MainActor in await controller.stop() } }
    }
}
