//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  MenuBarView.swift
//  Hydra Display
//
//  Compact menu-bar panel. The panel itself is a system Liquid Glass surface,
//  so the content here stays flat (no glass-on-glass) and uses standard
//  controls, which adopt the Tahoe look automatically.
//

import SwiftUI

struct MenuBarView: View {
    @Environment(DisplayManager.self) private var manager
    @Environment(Updater.self) private var updater
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            header

            if updater.phase == .available {
                updateRow
            }

            if !manager.isVirtualDisplaySupported {
                Label("Private virtual-display API unavailable on this macOS.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            activeDisplays

            Divider()

            Text("Quick create")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(spacing: Theme.Space.xs) {
                quickButton("4K Retina", subtitle: "3840 × 2160", w: 3840, h: 2160, hiDPI: true)
                quickButton("1440p Retina", subtitle: "2560 × 1440", w: 2560, h: 1440, hiDPI: true)
                quickButton("1080p", subtitle: "1920 × 1080", w: 1920, h: 1080, hiDPI: false)
            }

            Divider()

            HStack(spacing: Theme.Space.s) {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open \(AppInfo.name)", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Settings…")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Quit \(AppInfo.name)")
            }
        }
        .padding(Theme.Space.l)
        .frame(width: 300)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: AppInfo.symbol)
                .foregroundStyle(.tint)
            Text(AppInfo.name).font(.headline)
            Spacer()
            Text("\(manager.virtualHandles.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Space.s)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.6), in: Capsule())
        }
    }

    // MARK: Update row

    private var updateRow: some View {
        Button {
            openWindow(id: "about")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Update available").font(.callout.weight(.medium))
                    if let v = updater.availableVersion {
                        Text("Version \(v)")
                            .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.vertical, Theme.Space.xs)
            .padding(.horizontal, Theme.Space.s)
            .frame(maxWidth: .infinity)
            .background(.tint.opacity(0.14), in: Theme.card(Theme.Radius.chip))
            .contentShape(Theme.card(Theme.Radius.chip))
        }
        .buttonStyle(.plain)
    }

    // MARK: Active displays

    @ViewBuilder
    private var activeDisplays: some View {
        if manager.virtualHandles.isEmpty {
            Text("No virtual displays yet")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Space.xs)
        } else {
            VStack(spacing: Theme.Space.xs) {
                ForEach(manager.virtualHandles) { handle in
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "display").foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(handle.spec.name).font(.callout).lineLimit(1)
                            Text("\(handle.spec.maxPixelsWide) × \(handle.spec.maxPixelsHigh)")
                                .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                        }
                        Spacer()
                        Button {
                            manager.remove(handle)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(handle.spec.name)")
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, Theme.Space.s)
                    .background(.quaternary.opacity(0.4), in: Theme.card(Theme.Radius.chip))
                }
            }
        }
    }

    // MARK: Quick create

    private func quickButton(_ title: String, subtitle: String,
                             w: Int, h: Int, hiDPI: Bool) -> some View {
        Button {
            let mm = ResolutionPresets.millimeters(for: w, height: h, hiDPI: hiDPI)
            let spec = VirtualDisplaySpec(
                name: title, widthMillimeters: mm.w, heightMillimeters: mm.h,
                hiDPI: hiDPI,
                modes: [VirtualDisplayMode(width: w, height: h, refreshRate: 60)])
            manager.createVirtualDisplay(spec)
        } label: {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
                Text(title).fontWeight(.medium)
                Spacer()
                Text(subtitle)
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(!manager.isVirtualDisplaySupported)
    }
}
