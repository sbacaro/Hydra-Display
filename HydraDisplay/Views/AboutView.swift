//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  AboutView.swift
//  Hydra Display
//
//  Custom "About" window. All text comes from AppInfo — the single source of
//  truth for the app's edition.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            appIcon

            VStack(spacing: Theme.Space.xs) {
                Text(AppInfo.name)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(AppInfo.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(AppInfo.versionString)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, Theme.Space.xs)
                .background(.quaternary.opacity(0.5), in: Capsule())

            links

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(AppInfo.copyright)
                Text("Licensed under the \(AppInfo.licenseName).")
                Text(AppInfo.minimumOS)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .padding(Theme.Space.xl)
        .frame(width: 380, height: 460)
        .background(.regularMaterial)
    }

    private var appIcon: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: 116, height: 116)
            .accessibilityLabel("\(AppInfo.name) app icon")
    }

    private var links: some View {
        VStack(spacing: Theme.Space.s) {
            LinkButton(title: "View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right",
                       url: AppInfo.repositoryURL)
            LinkButton(title: "Releases & changelog", systemImage: "shippingbox",
                       url: AppInfo.releasesURL)
            HStack(spacing: Theme.Space.s) {
                LinkButton(title: "License", systemImage: "doc.text", url: AppInfo.licenseURL)
                LinkButton(title: "Report an issue", systemImage: "ladybug", url: AppInfo.issuesURL)
            }
        }
    }
}

/// A bordered link styled like the rest of the app, opening a URL.
private struct LinkButton: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
