//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  OverviewView.swift
//  Hydra Display
//
//  Landing pane: a grid of every screen attached to the Mac, grouped under a
//  clear section header. Cards are content (material); the only accent is the
//  tinted icon tiles and the highlighted virtual displays.
//

import SwiftUI

/// Shared inner content height so every card in the grid renders identically
/// (total card height = this + surfaceCard padding on both sides).
private let kCardContentHeight: CGFloat = 104

struct OverviewView: View {
    @Environment(DisplayManager.self) private var manager
    var onCreate: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 248, maximum: 360),
                                    spacing: Theme.Space.l)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                sectionHeader
                LazyVGrid(columns: columns, spacing: Theme.Space.l) {
                    ForEach(manager.allDisplays) { display in
                        DisplayCard(display: display)
                    }
                    AddDisplayCard(action: onCreate,
                                   enabled: manager.isVirtualDisplaySupported)
                }
            }
            .padding(Theme.Space.xl)
        }
        .navigationTitle("Overview")
        .scrollContentBackground(.hidden)
    }

    private var sectionHeader: some View {
        let total = manager.allDisplays.count
        let virtual = manager.virtualHandles.count
        return HStack(alignment: .firstTextBaseline) {
            Text("Displays")
                .font(.title3.weight(.semibold))
            Spacer()
            Text(virtual == 0
                 ? "\(total) connected"
                 : "\(total) connected · \(virtual) virtual")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.bottom, Theme.Space.xs)
    }
}

// MARK: - Display card

private struct DisplayCard: View {
    @Environment(DisplayManager.self) private var manager
    @Environment(\.openWindow) private var openWindow
    let display: DisplayInfo
    @State private var hovering = false

    private var handle: VirtualDisplayHandle? {
        display.isVirtualHydra ? manager.handle(for: display.id) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(alignment: .top, spacing: Theme.Space.m) {
                iconTile
                VStack(alignment: .leading, spacing: 3) {
                    Text(display.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(display.resolutionLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: Theme.Space.xs) {
                    if display.isMain { Badge(text: "Main", tint: .accentColor) }
                    if display.isMirrored {
                        Badge(text: "Mirrored", systemImage: "rectangle.on.rectangle")
                    }
                }
            }

            Spacer(minLength: Theme.Space.s)

            footer
        }
        .frame(maxWidth: .infinity, minHeight: kCardContentHeight,
               maxHeight: kCardContentHeight, alignment: .topLeading)
        .surfaceCard(tinted: display.isVirtualHydra)
        .shadow(color: .black.opacity(hovering ? 0.16 : 0.05),
                radius: hovering ? 12 : 4, y: hovering ? 5 : 2)
        .animation(.smooth(duration: 0.18), value: hovering)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Open as Picture in Picture", systemImage: "pip") {
                openWindow(id: "pip", value: CaptureSource.display(display.id, title: display.name))
            }
            if let handle {
                Button("Remove", systemImage: "trash", role: .destructive) {
                    manager.remove(handle)
                }
            }
        }
    }

    private var iconTile: some View {
        Image(systemName: display.isVirtualHydra ? "display" : "desktopcomputer")
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(display.isVirtualHydra ? AnyShapeStyle(.tint)
                                                    : AnyShapeStyle(.secondary))
            .frame(width: 40, height: 40)
            .background(
                display.isVirtualHydra ? AnyShapeStyle(Color.accentColor.opacity(0.14))
                                       : AnyShapeStyle(.quaternary.opacity(0.6)),
                in: Theme.card(Theme.Radius.inner))
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.s) {
            Label(display.isVirtualHydra ? "Virtual display" : "Physical display",
                  systemImage: display.isVirtualHydra ? "sparkles" : "cable.connector")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ResolutionMenu(displayID: display.id, compact: true)
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(.secondary)
            if let handle {
                Button {
                    manager.remove(handle)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove \(display.name)")
            }
        }
    }
}

// MARK: - Add card (subtle, not loud)

private struct AddDisplayCard: View {
    var action: () -> Void
    var enabled: Bool
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.s) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
                    .background(.tint.opacity(0.14), in: Theme.card(Theme.Radius.inner))
                Text("New Virtual Display")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: kCardContentHeight,
                   maxHeight: kCardContentHeight)
            .surfaceCard()
            .overlay {
                Theme.card().strokeBorder(.tint.opacity(hovering ? 0.55 : 0.3), lineWidth: 1)
            }
            .contentShape(Theme.card())
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(hovering ? 0.16 : 0.05),
                radius: hovering ? 12 : 4, y: hovering ? 5 : 2)
        .opacity(enabled ? 1 : 0.4)
        .animation(.smooth(duration: 0.18), value: hovering)
        .onHover { hovering = $0 }
        .disabled(!enabled)
    }
}
