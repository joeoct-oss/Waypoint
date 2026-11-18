//
//  SplashView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The first screen: the brand while the app starts. It reports when it is done, and the app
// coordinator picks the next root. The launch options set how long it stays.
struct SplashView: View {
    let duration: Duration
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.accent.color)
            Text("Orbit Shop")
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
            Text("A Waypoint example app")
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
        try? await Task.sleep(for: duration)
        onFinished()
    }
}
