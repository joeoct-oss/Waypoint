//
//  SplashView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The first screen: the brand while the app starts. It reports when it is done, and the app coordinator
// picks the next root.
struct SplashView: View {
    private static let duration = Duration.seconds(1)

    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.accent.color)
            Text("Waypoint")
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
            Text("Connect every screen. Know every route.")
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.splash)
        .task { await finish() }
    }

    private func finish() async {
        try? await Task.sleep(for: Self.duration)
        onFinished()
    }
}
