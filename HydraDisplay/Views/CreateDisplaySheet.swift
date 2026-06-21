//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  CreateDisplaySheet.swift
//  Hydra Display
//
//  Guided creation of a virtual display: name, HiDPI, and which resolution
//  modes it should advertise (plus a custom one).
//

import SwiftUI

struct CreateDisplaySheet: View {
    @Environment(DisplayManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var name = AppInfo.name
    @State private var hiDPI = true
    @State private var selectedPresets: Set<ResolutionPresets.Preset> =
        Set(ResolutionPresets.defaultModes.compactMap { mode in
            ResolutionPresets.all.first { $0.width == mode.width && $0.height == mode.height }
        })
    @State private var customWidth = ""
    @State private var customHeight = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canCreate: Bool { !selectedPresets.isEmpty && !trimmedName.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    nameSection
                    presetSection
                    customSection
                }
                .padding(Theme.Space.xl)
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 660)
        .background(.windowBackground)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: "display.and.arrow.down")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.12), in: Theme.card(Theme.Radius.inner))
            VStack(alignment: .leading, spacing: 2) {
                Text("New Virtual Display").font(.title2.bold())
                Text("It appears to macOS as a real monitor.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Theme.Space.xl)
    }

    // MARK: Sections

    private var nameSection: some View {
        SectionCard("Display", systemImage: "display") {
            LabeledContent("Name") {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
            }
            Divider()
            Toggle(isOn: $hiDPI) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("HiDPI (Retina)")
                    Text("Renders crisp at 2× — recommended.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var presetSection: some View {
        SectionCard("Resolutions to advertise", systemImage: "ruler") {
            ForEach(Array(ResolutionPresets.groups.enumerated()), id: \.element.title) { index, group in
                if index > 0 { Divider() }
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(group.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    FlowChips(presets: group.presets, selection: $selectedPresets)
                }
            }
        }
    }

    private var customSection: some View {
        SectionCard("Custom resolution", systemImage: "plus.rectangle") {
            HStack(spacing: Theme.Space.s) {
                TextField("Width", text: $customWidth)
                    .textFieldStyle(.roundedBorder).frame(width: 92)
                    .monospacedDigit()
                Text("×").foregroundStyle(.secondary)
                TextField("Height", text: $customHeight)
                    .textFieldStyle(.roundedBorder).frame(width: 92)
                    .monospacedDigit()
                Spacer()
                Button("Add", systemImage: "plus") { addCustom() }
                    .buttonStyle(.bordered)
                    .disabled(Int(customWidth) == nil || Int(customHeight) == nil)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text(selectedPresets.count == 1 ? "1 resolution"
                                            : "\(selectedPresets.count) resolutions")
                .font(.callout).foregroundStyle(.secondary).monospacedDigit()
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Button("Create Display") { create() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
        }
        .padding(Theme.Space.l)
        .background(.bar)
    }

    // MARK: Actions

    private func addCustom() {
        guard let w = Int(customWidth), let h = Int(customHeight), w > 100, h > 100 else { return }
        selectedPresets.insert(ResolutionPresets.Preset(name: "Custom", width: w, height: h))
        customWidth = ""; customHeight = ""
    }

    private func create() {
        let modes = selectedPresets
            .sorted { $0.width * $0.height > $1.width * $1.height }
            .map { $0.mode() }
        let largest = modes.first ?? ResolutionPresets.defaultModes[0]
        let mm = ResolutionPresets.millimeters(for: largest.width,
                                               height: largest.height, hiDPI: hiDPI)
        let spec = VirtualDisplaySpec(
            name: trimmedName,
            widthMillimeters: mm.w, heightMillimeters: mm.h,
            hiDPI: hiDPI, modes: modes)
        if manager.createVirtualDisplay(spec) != nil {
            dismiss()
        }
    }
}

// MARK: - Wrapping chip selector (content layer — no glass)

struct FlowChips: View {
    let presets: [ResolutionPresets.Preset]
    @Binding var selection: Set<ResolutionPresets.Preset>

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 170),
                                    spacing: Theme.Space.s)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Space.s) {
            ForEach(presets) { preset in
                chip(preset)
            }
        }
    }

    private func chip(_ preset: ResolutionPresets.Preset) -> some View {
        let isOn = selection.contains(preset)
        return Button {
            if isOn { selection.remove(preset) } else { selection.insert(preset) }
        } label: {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 0) {
                    Text(preset.name).font(.caption.weight(.semibold))
                    Text("\(preset.width)×\(preset.height)")
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.s)
            .padding(.vertical, Theme.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Theme.card(Theme.Radius.chip)
                    .fill(isOn ? AnyShapeStyle(Color.accentColor.opacity(0.14))
                               : AnyShapeStyle(.quaternary.opacity(0.6)))
            }
            .overlay {
                Theme.card(Theme.Radius.chip)
                    .strokeBorder(isOn ? Color.accentColor.opacity(0.5) : .clear,
                                  lineWidth: 1)
            }
            .contentShape(Theme.card(Theme.Radius.chip))
        }
        .buttonStyle(.plain)
    }
}
