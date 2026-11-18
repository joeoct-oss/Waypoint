//
//  AccountView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Account: the reader's profile with Sign out, or Sign in for a guest, and Orders, Addresses and
// Settings for everyone. The screen reports each choice; the account coordinator decides what needs an account.
struct AccountView: View {
    let account: Account?
    let onSignIn: () -> Void
    let onShowOrders: () -> Void
    let onShowAddresses: () -> Void
    let onShowSettings: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        List {
            Section {
                header
            }
            Section {
                Button("Orders", systemImage: "shippingbox", action: onShowOrders)
                    .accessibilityIdentifier(Identifiers.ordersButton)
                Button("Addresses", systemImage: "mappin.and.ellipse", action: onShowAddresses)
                    .accessibilityIdentifier(Identifiers.addressesButton)
                Button("Settings", systemImage: "gearshape", action: onShowSettings)
                    .accessibilityIdentifier(Identifiers.settingsButton)
            }
            signOutSection
        }
        .exampleList()
    }

    @ViewBuilder
    private var header: some View {
        if let account {
            makeProfile(account)
        } else {
            signInPrompt
        }
    }

    @ViewBuilder
    private var signOutSection: some View {
        if account != nil {
            Section {
                Button("Sign out", role: .destructive, action: onSignOut)
                    .accessibilityIdentifier(Identifiers.signOut)
            }
        }
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Sign in to see your orders and save products.")
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary.color)
            PrimaryActionButton(
                title: "Sign in or create account",
                identifier: Identifiers.accountSignIn,
                action: onSignIn
            )
        }
        .padding(.vertical, Spacing.extraSmall)
    }

    private func makeProfile(_ account: Account) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.brand.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Typography.headline)
                    .accessibilityIdentifier(Identifiers.accountName)
                Text(account.email)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .padding(.vertical, Spacing.extraSmall)
    }
}
