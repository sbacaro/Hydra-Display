//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  ContentView.swift
//  Hydra Display
//
//  Two-column shell. The sidebar and toolbar adopt Liquid Glass automatically
//  on macOS Tahoe; content panes stay on the material/content layer.
//

import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case arrangement
    case profiles
    case pip
    case display(UUID)
}

struct ContentView: View {
    @Environment(DisplayManager.self) private var manager
    @Environment(Updater.self) private var updater
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @State private var selection: SidebarItem? = .overview
    @State private var showingCreateSheet = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 224, ideal: 252, max: 320)
                .safeAreaInset(edge: .bottom) {
                    if updater.phase == .available { updateBanner }
                }
        } detail: {
            detail
                .toolbar { toolbarContent }
                .sheet(isPresented: onboardingBinding) {
                    OnboardingView().environment(settings)
                }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateDisplaySheet()
                .environment(manager)
        }
        .overlay(alignment: .bottom) {
            if !manager.isVirtualDisplaySupported {
                unsupportedBanner
            }
        }
        .alert("Display error",
               isPresented: Binding(
                get: { manager.lastError != nil },
                set: { if !$0 { manager.lastError = nil } })) {
            Button("OK", role: .cancel) { manager.lastError = nil }
        } message: {
            Text(manager.lastError ?? "")
        }
    }

    // MARK: Onboarding

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !settings.hasCompletedOnboarding && !AppEnvironment.isUnitTesting },
            set: { presented in if !presented { settings.hasCompletedOnboarding = true } })
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingCreateSheet = true
            } label: {
                Label("New Virtual Display", systemImage: "plus")
            }
            .help("Create a new virtual display")
            .disabled(!manager.isVirtualDisplaySupported)
        }
    }

    // MARK: Update banner (sidebar footer)

    private var updateBanner: some View {
        Button {
            openWindow(id: "about")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Update available")
                        .font(.callout.weight(.medium))
                    if let v = updater.availableVersion {
                        Text("Version \(v)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Space.s)
            .background(.tint.opacity(0.12), in: Theme.card(Theme.Radius.inner))
            .overlay {
                Theme.card(Theme.Radius.inner)
                    .strokeBorder(.tint.opacity(0.3), lineWidth: 1)
            }
            .contentShape(Theme.card(Theme.Radius.inner))
        }
        .buttonStyle(.plain)
        .padding(Theme.Space.s)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                Label("Overview", systemImage: "square.grid.2x2")
                    .tag(SidebarItem.overview)
                Label("Arrangement & Mirroring", systemImage: "rectangle.3.group")
                    .tag(SidebarItem.arrangement)
                Label("Profiles", systemImage: "square.stack.3d.up")
                    .tag(SidebarItem.profiles)
                Label("Picture in Picture", systemImage: "pip")
                    .tag(SidebarItem.pip)
            }

            Section {
                if manager.virtualHandles.isEmpty {
                    Label {
                        Text("No virtual displays")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "rectangle.dashed")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.callout)
                }
                ForEach(manager.virtualHandles) { handle in
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(handle.spec.name)
                                .lineLimit(1)
                            Text("\(handle.spec.maxPixelsWide) × \(handle.spec.maxPixelsHigh)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: "display")
                            .foregroundStyle(.tint)
                    }
                    .tag(SidebarItem.display(handle.id))
                }
            } header: {
                Text("Virtual Displays")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(AppInfo.name)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview, .none:
            OverviewView(onCreate: { showingCreateSheet = true })
        case .arrangement:
            ArrangementView()
        case .profiles:
            ProfilesView()
        case .pip:
            PiPSourcePickerView()
        case .display(let id):
            if let handle = manager.virtualHandles.first(where: { $0.id == id }) {
                DisplayDetailView(handle: handle)
            } else {
                ContentUnavailableView("Display removed",
                                       systemImage: "display.trianglebadge.exclamationmark",
                                       description: Text("This virtual display is no longer active."))
            }
        }
    }

    // MARK: Banner (floating glass — single control-layer element)

    private var unsupportedBanner: some View {
        Label {
            Text("Virtual displays aren't available on this macOS build — the private CoreGraphics API is missing.")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .font(.callout)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .glassEffect(.regular, in: .capsule)
        .padding(.bottom, Theme.Space.l)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}
