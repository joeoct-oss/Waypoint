//
//  WelcomeView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Welcome: the shop's name and three ways in. The screen reports the choice, and the accounts coordinator
// decides where it goes.
struct WelcomeView: View {
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void
    let onContinueAsGuest: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Spacer()
            brand
            Spacer()
            PrimaryActionButton(
                title: "Create account",
                identifier: Identifiers.welcomeCreateAccount,
                action: onCreateAccount
            )
            secondaryButton(
                "Sign in",
                identifier: Identifiers.welcomeSignIn,
                action: onSignIn
            )
            Button("Continue as guest", action: onContinueAsGuest)
                .font(Typography.callout.weight(.semibold))
                .frame(minHeight: Size.minimumTouchTarget)
                .accessibilityIdentifier(Identifiers.welcomeGuest)
        }
        .padding(Spacing.large)
    }

    private var brand: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.accent.color)
                .accessibilityHidden(true)
            Text("Orbit Shop")
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
            Text("Lamps, mugs and prints for night owls.")
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .multilineTextAlignment(.center)
    }

    private func secondaryButton(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
    }
}
