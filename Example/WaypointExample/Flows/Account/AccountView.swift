//
//  AccountView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Account: the reader's profile, with orders, settings and sign out.
struct AccountView: View {
    let onShowOrders: () -> Void
    let onShowSettings: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        List {
            Section {
                profile
            }
            Section {
                Button("Orders", systemImage: "shippingbox", action: onShowOrders)
                Button("Settings", systemImage: "gearshape", action: onShowSettings)
                    .accessibilityIdentifier(Identifiers.settingsButton)
            }
            Section {
                Button("Sign out", role: .destructive, action: onSignOut)
            }
        }
        .exampleList()
    }

    private var profile: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.brand.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nova Reader")
                    .font(Typography.headline)
                Text("nova@example.com")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .padding(.vertical, Spacing.extraSmall)
    }
}
