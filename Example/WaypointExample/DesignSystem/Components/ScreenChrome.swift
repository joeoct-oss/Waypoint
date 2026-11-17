//
//  ScreenChrome.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// What every screen shows around its content: the title, the kind when the screen belongs to one kind,
// and the route trail.
//
// From iOS 26 the system bars are Liquid Glass, so the chrome stays inside them: the trail is the
// navigation bar's subtitle, the kind is a plain toolbar item that the bar draws in glass, and content
// scrolls under the bars. Earlier systems show the trail as a strip on the bar material below the bar.
//
// Conformances:
// - `ViewModifier`, so the app coordinator gives every screen the same chrome with `.screenChrome(...)`.
struct ScreenChrome: ViewModifier {
    // The strip's material stays inside the safe area, so it never covers the navigation bar.
    private static let trailBackdropEdges: Edge.Set = []

    let title: String
    let kind: FlowKind?
    let trail: [String]

    private var trailText: String {
        trail.joined(separator: " › ")
    }

    private var trailStrip: some View {
        RouteTrail(steps: trail)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .background(.bar, ignoresSafeAreaEdges: Self.trailBackdropEdges)
    }

    @ToolbarContentBuilder
    private var kindItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if let kind {
                KindChip(kind: kind)
            }
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            makeGlassChrome(content)
        } else {
            makeClassicChrome(content)
        }
    }

    @available(iOS 26.0, *)
    private func makeGlassChrome(_ content: Content) -> some View {
        content
            .background(Palette.background.color)
            .navigationTitle(title)
            .navigationSubtitle(trailText)
            .toolbar { kindItem }
    }

    private func makeClassicChrome(_ content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) { trailStrip }
            .background(Palette.background.color)
            .navigationTitle(title)
            .toolbar { kindItem }
    }
}

extension View {
    func screenChrome(
        title: String,
        kind: FlowKind?,
        trail: [String]
    ) -> some View {
        let chrome = ScreenChrome(
            title: title,
            kind: kind,
            trail: trail
        )
        return modifier(chrome)
    }
}
