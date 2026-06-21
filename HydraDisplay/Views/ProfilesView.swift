//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  ProfilesView.swift
//  Hydra Display
//
//  Save the current set of virtual displays as a named profile and re-apply it
//  later with one click.
//

import SwiftUI

struct ProfilesView: View {
    @Environment(DisplayManager.self) private var manager
    @State private var newName = ""

    private var canSave: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty
            && !manager.virtualHandles.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                saveSection
                listSection
            }
            .padding(Theme.Space.xl)
        }
        .navigationTitle("Profiles")
        .scrollContentBackground(.hidden)
    }

    private var saveSection: some View {
        SectionCard("Save current setup", systemImage: "square.and.arrow.down") {
            HStack(spacing: Theme.Space.s) {
                TextField("Profile name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            Text(manager.virtualHandles.isEmpty
                 ? "Create some virtual displays first, then save them as a profile."
                 : "Saves your \(manager.virtualHandles.count) current virtual display(s) as a named set.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var listSection: some View {
        SectionCard("Saved profiles", systemImage: "square.stack.3d.up") {
            if manager.profiles.isEmpty {
                Text("No profiles yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(manager.profiles.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { Divider() }
                    row(profile)
                }
            }
        }
    }

    private func row(_ profile: DisplayProfile) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name).font(.headline)
                Text(profile.displayCount == 1 ? "1 display"
                                               : "\(profile.displayCount) displays")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Apply") { manager.applyProfile(profile) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!manager.isVirtualDisplaySupported)
            Button(role: .destructive) {
                manager.deleteProfile(profile)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Delete “\(profile.name)”")
        }
    }

    private func save() {
        guard canSave else { return }
        manager.saveCurrentAsProfile(named: newName)
        newName = ""
    }
}
