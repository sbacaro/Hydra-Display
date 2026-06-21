//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  ColorControlsView.swift
//  Hydra Display
//
//  Brightness + color-temperature sliders for a single display, backed by the
//  GammaController. Used inline in the display detail pane and inside a popover
//  on the Overview cards.
//

import SwiftUI

struct DisplayColorControls: View {
    @Environment(GammaController.self) private var gamma
    let displayID: CGDirectDisplayID

    private var adjustment: ColorAdjustment { gamma.adjustment(for: displayID) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            slider(
                title: "Brightness",
                systemImage: "sun.max",
                value: Binding(get: { gamma.adjustment(for: displayID).brightness },
                               set: { gamma.setBrightness($0, for: displayID) }),
                range: ColorAdjustment.minBrightness...1.0,
                minIcon: "sun.min", maxIcon: "sun.max.fill",
                percent: Int((adjustment.brightness * 100).rounded()))

            slider(
                title: "Color temperature",
                systemImage: "thermometer.medium",
                value: Binding(get: { gamma.adjustment(for: displayID).temperature },
                               set: { gamma.setTemperature($0, for: displayID) }),
                range: -1.0...1.0,
                minIcon: "flame", maxIcon: "snowflake",
                percent: nil,
                caption: temperatureCaption(adjustment.temperature))

            HStack {
                Spacer()
                Button("Reset") { gamma.reset(displayID) }
                    .controlSize(.small)
                    .disabled(adjustment.isNeutral)
            }
        }
    }

    @ViewBuilder
    private func slider(title: LocalizedStringKey, systemImage: String,
                        value: Binding<Double>, range: ClosedRange<Double>,
                        minIcon: String, maxIcon: String,
                        percent: Int?, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack {
                Label(title, systemImage: systemImage).font(.subheadline)
                Spacer()
                if let percent {
                    Text("\(percent)%").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                } else if let caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: Theme.Space.s) {
                Image(systemName: minIcon).font(.caption).foregroundStyle(.secondary)
                Slider(value: value, in: range)
                Image(systemName: maxIcon).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func temperatureCaption(_ t: Double) -> String {
        if abs(t) < 0.001 { return "Neutral" }
        return t < 0 ? "Warm" : "Cool"
    }
}
