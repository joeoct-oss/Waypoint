//
//  ScreenChrome.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// What every screen shows around its content: the title in the navigation bar, the kind chip when the
// screen belongs to one kind, and the route trail under the bar.
//
// Conformances:
// - `ViewModifier`, so the app coordinator gives every screen the same chrome with `.screenChrome(...)`.
struct ScreenChrome: ViewModifier {
    let title: String
    let kind: FlowKind?
    let trail: [String]

    private var trailStrip: some View {
        RouteTrail(steps: trail)
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.small)
            .background(Palette.background.color)
    }

    @ToolbarContentBuilder
    private var kindChip: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if let kind {
                KindChip(kind: kind)
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) { trailStrip }
            .background(Palette.background.color)
            .navigationTitle(title)
            .toolbar { kindChip }
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
