//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  ArrangementView.swift
//  Hydra Display
//
//  Visual desktop arrangement (drag tiles to reposition) plus a per-display
//  mirroring control. Both use the public CoreGraphics display-configuration
//  API, so they work for real and virtual displays alike.
//

import SwiftUI

struct ArrangementView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                SectionCard("Arrangement", systemImage: "rectangle.3.group") {
                    Text("Drag a display to change where it sits in the desktop space.")
                        .font(.caption).foregroundStyle(.secondary)
                    ArrangementCanvas()
                        .frame(height: 300)
                }
                MirrorMatrix()
            }
            .padding(Theme.Space.xl)
        }
        .navigationTitle("Arrangement & Mirroring")
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Draggable canvas

private struct ArrangementCanvas: View {
    @Environment(DisplayManager.self) private var manager
    @State private var dragOffsets: [CGDirectDisplayID: CGSize] = [:]

    var body: some View {
        GeometryReader { geo in
            let layout = layout(in: geo.size)
            ZStack {
                ForEach(manager.allDisplays) { display in
                    let frame = layout.frames[display.id] ?? .zero
                    tile(display, dragging: dragOffsets[display.id] != nil)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX + (dragOffsets[display.id]?.width ?? 0),
                                  y: frame.midY + (dragOffsets[display.id]?.height ?? 0))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffsets[display.id] = value.translation
                                }
                                .onEnded { value in
                                    commitDrag(display: display, translation: value.translation,
                                               scale: layout.scale)
                                    dragOffsets[display.id] = nil
                                }
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(.quaternary.opacity(0.4), in: Theme.card())
        .overlay {
            Theme.card().strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        }
    }

    private func tile(_ display: DisplayInfo, dragging: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: display.isVirtualHydra ? "display" : "desktopcomputer")
                .font(.system(size: 16))
            Text(display.name).font(.caption2.weight(.medium)).lineLimit(1)
            Text(display.resolutionLabel)
                .font(.system(size: 9)).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(Theme.Space.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: Theme.card(Theme.Radius.inner))
        .overlay {
            Theme.card(Theme.Radius.inner)
                .strokeBorder(
                    display.isMain ? AnyShapeStyle(Color.accentColor)
                                   : AnyShapeStyle(.separator),
                    lineWidth: display.isMain ? 2 : 1)
        }
        .shadow(color: .black.opacity(dragging ? 0.25 : 0.08),
                radius: dragging ? 10 : 3, y: dragging ? 5 : 1)
        .scaleEffect(dragging ? 1.04 : 1)
        .animation(.smooth(duration: 0.18), value: dragging)
    }

    private func commitDrag(display: DisplayInfo, translation: CGSize, scale: CGFloat) {
        guard scale > 0 else { return }
        let newOrigin = CGPoint(
            x: display.origin.x + translation.width / scale,
            y: display.origin.y + translation.height / scale)
        manager.setOrigin(display.id, to: newOrigin)
    }

    // Map global display bounds into the canvas, preserving relative positions.
    private func layout(in size: CGSize) -> (frames: [CGDirectDisplayID: CGRect], scale: CGFloat) {
        let displays = manager.allDisplays
        guard !displays.isEmpty else { return ([:], 1) }

        let minX = displays.map { $0.origin.x }.min() ?? 0
        let minY = displays.map { $0.origin.y }.min() ?? 0
        let maxX = displays.map { $0.origin.x + CGFloat($0.pixelWidth) }.max() ?? 1
        let maxY = displays.map { $0.origin.y + CGFloat($0.pixelHeight) }.max() ?? 1

        let totalW = max(maxX - minX, 1)
        let totalH = max(maxY - minY, 1)
        let padding: CGFloat = 40
        let scale = min((size.width - padding) / totalW, (size.height - padding) / totalH)

        let contentW = totalW * scale
        let contentH = totalH * scale
        let offsetX = (size.width - contentW) / 2
        let offsetY = (size.height - contentH) / 2

        var frames: [CGDirectDisplayID: CGRect] = [:]
        for d in displays {
            frames[d.id] = CGRect(
                x: offsetX + (d.origin.x - minX) * scale,
                y: offsetY + (d.origin.y - minY) * scale,
                width: CGFloat(d.pixelWidth) * scale,
                height: CGFloat(d.pixelHeight) * scale)
        }
        return (frames, scale)
    }
}

// MARK: - Mirror matrix

private struct MirrorMatrix: View {
    @Environment(DisplayManager.self) private var manager

    var body: some View {
        SectionCard("Mirroring", systemImage: "rectangle.on.rectangle") {
            ForEach(Array(manager.allDisplays.enumerated()), id: \.element.id) { index, display in
                if index > 0 { Divider() }
                HStack {
                    Label(display.name,
                          systemImage: display.isVirtualHydra ? "display" : "desktopcomputer")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: mirrorBinding(for: display)) {
                        Text("Off").tag(CGDirectDisplayID(0))
                        ForEach(manager.allDisplays.filter { $0.id != display.id }) { other in
                            Text("Mirror \(other.name)").tag(other.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                }
            }
        }
    }

    private func mirrorBinding(for display: DisplayInfo) -> Binding<CGDirectDisplayID> {
        Binding(
            get: { display.mirrorSourceID ?? 0 },
            set: { newSource in
                if newSource == 0 {
                    manager.stopMirroring(display.id)
                } else {
                    manager.mirror(display.id, onto: newSource)
                }
            })
    }
}
