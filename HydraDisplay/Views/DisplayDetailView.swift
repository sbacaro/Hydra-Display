//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  DisplayDetailView.swift
//  Hydra Display
//
//  Detail pane for a single Hydra virtual display: identity, advertised
//  resolutions, HiDPI state, quick mirror, and removal.
//

import SwiftUI

struct DisplayDetailView: View {
    @Environment(DisplayManager.self) private var manager
    @Environment(\.openWindow) private var openWindow
    let handle: VirtualDisplayHandle

    private var liveInfo: DisplayInfo? {
        manager.allDisplays.first { $0.id == handle.cgDisplayID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                hero
                identitySection
                resolutionSection
                modesSection
                mirrorSection
                viewerButton
                removeButton
            }
            .padding(Theme.Space.xl)
        }
        .navigationTitle(handle.spec.name)
        .scrollContentBackground(.hidden)
    }

    // MARK: Hero

    private var hero: some View {
        HStack(spacing: Theme.Space.l) {
            Image(systemName: "display")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .background(.tint.opacity(0.12), in: Theme.card())
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(handle.spec.name).font(.title2.bold())
                HStack(spacing: Theme.Space.s) {
                    Badge(text: handle.spec.hiDPI ? "Retina" : "Standard",
                          systemImage: "sparkles", tint: .accentColor)
                    Badge(text: liveInfo == nil ? "Initialising…" : "Active",
                          systemImage: liveInfo == nil ? "clock" : "checkmark.circle",
                          tint: liveInfo == nil ? .orange : .green)
                    if liveInfo?.isMirrored == true {
                        Badge(text: "Mirrored", systemImage: "rectangle.on.rectangle")
                    }
                }
            }
            Spacer()
        }
        .surfaceCard(tinted: true)
    }

    private var identitySection: some View {
        SectionCard("Identity", systemImage: "info.circle") {
            InfoRow(label: "Display ID", value: liveInfo.map { "\($0.id)" } ?? "—")
            Divider()
            InfoRow(label: "Maximum resolution",
                    value: "\(handle.spec.maxPixelsWide) × \(handle.spec.maxPixelsHigh)")
            Divider()
            InfoRow(label: "HiDPI", value: handle.spec.hiDPI ? "On (2×)" : "Off")
        }
    }

    private var resolutionSection: some View {
        SectionCard("Resolution", systemImage: "slider.horizontal.3") {
            if liveInfo != nil {
                HStack {
                    Text("Active resolution").foregroundStyle(.secondary)
                    Spacer()
                    ResolutionMenu(displayID: handle.cgDisplayID)
                }
                Text("Switch the live resolution of this display.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Waiting for the display to come online…")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var modesSection: some View {
        SectionCard("Advertised resolutions", systemImage: "ruler") {
            ForEach(Array(handle.spec.modes.enumerated()), id: \.element.id) { index, mode in
                if index > 0 { Divider() }
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: "rectangle")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(mode.label).monospacedDigit()
                        if handle.spec.hiDPI {
                            Text("Looks like \(mode.hiDPIPointSize.w) × \(mode.hiDPIPointSize.h)")
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    Spacer()
                    Text("\(Int(mode.refreshRate)) Hz")
                        .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    private var mirrorSection: some View {
        SectionCard("Mirror", systemImage: "rectangle.on.rectangle") {
            let others = manager.allDisplays.filter { $0.id != handle.cgDisplayID }
            if others.isEmpty {
                Text("No other displays to mirror.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Show another screen's contents on this virtual display.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(others.enumerated()), id: \.element.id) { index, other in
                    if index > 0 { Divider() }
                    HStack {
                        Label(other.name,
                              systemImage: other.isVirtualHydra ? "display" : "desktopcomputer")
                            .font(.subheadline)
                        Spacer()
                        Button("Mirror") {
                            manager.mirror(handle.cgDisplayID, onto: other.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                if liveInfo?.isMirrored == true {
                    Divider()
                    Button("Stop mirroring", systemImage: "rectangle.slash") {
                        manager.stopMirroring(handle.cgDisplayID)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var viewerButton: some View {
        Button {
            openWindow(id: "pip", value: CaptureSource.display(handle.cgDisplayID,
                                                               title: handle.spec.name))
        } label: {
            Label("Open as Picture in Picture", systemImage: "pip")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(liveInfo == nil)
    }

    private var removeButton: some View {
        Button(role: .destructive) {
            manager.remove(handle)
        } label: {
            Label("Remove this virtual display", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.red)
    }
}
