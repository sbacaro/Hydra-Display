//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  OnboardingView.swift
//  Hydra Display
//
//  First-run welcome. Explains what the app does and the private-API/Gatekeeper
//  caveat, then marks onboarding complete.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 104, height: 104)

            VStack(spacing: Theme.Space.xs) {
                Text("Welcome to \(AppInfo.name)")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(AppInfo.tagline)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Theme.Space.m) {
                feature("plus.rectangle.on.rectangle", "Create virtual displays",
                        "Add HiDPI/Retina screens in a couple of clicks.")
                feature("slider.horizontal.3", "Switch resolutions live",
                        "Change the active resolution of any display from its card.")
                feature("rectangle.on.rectangle", "Mirror & arrange",
                        "Rearrange the desktop space and mirror screens onto each other.")
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: Theme.card())

            Label("Hydra uses a private macOS API, so it isn't notarized. A downloaded "
                  + "build may need a right-click → Open the first time.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Get Started") {
                settings.hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(Theme.Space.xxl)
        .frame(width: 460, height: 580)
        .background(.windowBackground)
    }

    private func feature(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
