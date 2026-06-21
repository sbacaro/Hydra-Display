//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  DesignSystem.swift
//  Hydra Display
//
//  Shared visual language for a consistent macOS Tahoe / Liquid Glass look.
//
//  Hierarchy rule (per Apple HIG):
//    • CONTENT (cards, rows, sections) lives on the *material* layer.
//    • Liquid GLASS is reserved for the floating CONTROL layer (toolbars,
//      prominent action buttons, the menu-bar panel, banners) and is never
//      stacked glass-on-glass.
//

import SwiftUI

// MARK: - Tokens

enum Theme {
    enum Space {
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 12
        static let l:  CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }
    enum Radius {
        static let card: CGFloat = 16
        static let inner: CGFloat = 10
        static let chip: CGFloat = 9
    }
    /// Continuous rounded rectangle — matches macOS concentric corners.
    static func card(_ radius: CGFloat = Radius.card) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - Content surface (material, not glass)

private struct SurfaceCard: ViewModifier {
    var radius: CGFloat = Theme.Radius.card
    var padding: CGFloat = Theme.Space.l
    var tinted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: Theme.card(radius))
            .overlay {
                Theme.card(radius)
                    .strokeBorder(
                        tinted ? AnyShapeStyle(Color.accentColor.opacity(0.45))
                               : AnyShapeStyle(.separator.opacity(0.5)),
                        lineWidth: tinted ? 1 : 0.5)
            }
            .overlay {
                if tinted {
                    Theme.card(radius).fill(Color.accentColor.opacity(0.06))
                }
            }
    }
}

extension View {
    /// Standard content card: material background, hairline border, optional tint.
    func surfaceCard(radius: CGFloat = Theme.Radius.card,
                     padding: CGFloat = Theme.Space.l,
                     tinted: Bool = false) -> some View {
        modifier(SurfaceCard(radius: radius, padding: padding, tinted: tinted))
    }
}

// MARK: - Section card (titled content group)

struct SectionCard<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    init(_ title: String, systemImage: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Text(title)
                    .font(.headline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

// MARK: - Info row (label / value)

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Space.l)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(valueColor ?? .primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

// MARK: - Badge (subtle, content-layer pill — no glass)

struct Badge: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Space.s)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
    }
}
