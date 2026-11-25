//
//  AccountView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// Account (MA-03, AU-05): the reader's profile, or for a guest the "Sign in or create account"
// prompt, then Orders and Wish list with their counts, Addresses for a signed-in reader, and
// Settings. For a guest, Orders and Wish list say "Needs an account". The screen reports each
// choice; the account coordinator decides what needs an account. Sign out lives in Settings.
struct AccountView: View {
    private static let needsAccount = "Needs an account"

    let account: Account?
    let wishlistCount: () -> Int
    let onSignIn: () -> Void
    let onShowOrders: () -> Void
    let onShowWishlist: () -> Void
    let onShowAddresses: () -> Void
    let onShowSettings: () -> Void

    // `var` because the wish list changes in other tabs, so the screen reads its count each time it
    // appears.
    @State private var savedCount = 0

    private var ordersDetail: String {
        account == nil ? Self.needsAccount : "\(Order.onTheirWayCount) on its way"
    }

    private var wishlistDetail: String {
        account == nil ? Self.needsAccount : "\(savedCount) saved"
    }

    var body: some View {
        List {
            Section {
                header
            }
            Section {
                makeRow(
                    "Orders",
                    symbolName: "shippingbox",
                    detail: ordersDetail,
                    action: onShowOrders
                )
                .accessibilityIdentifier(Identifiers.ordersButton)
                makeRow(
                    "Wish list",
                    symbolName: "heart",
                    detail: wishlistDetail,
                    action: onShowWishlist
                )
                .accessibilityIdentifier(Identifiers.accountWishlist)
                addressesRow
                makeRow(
                    "Settings",
                    symbolName: "gearshape",
                    detail: nil,
                    action: onShowSettings
                )
                .accessibilityIdentifier(Identifiers.settingsButton)
            }
        }
        .exampleList()
        .onAppear { savedCount = wishlistCount() }
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
    private var addressesRow: some View {
        if account != nil {
            makeRow(
                "Addresses",
                symbolName: "mappin.and.ellipse",
                detail: nil,
                action: onShowAddresses
            )
            .accessibilityIdentifier(Identifiers.addressesButton)
        }
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Sign in or create account")
                .font(Typography.headline)
                .foregroundStyle(Palette.text.color)
            Text("Keep your cart on every device, save products and track orders.")
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary.color)
            PrimaryActionButton(
                title: "Sign in",
                identifier: Identifiers.accountSignIn,
                action: onSignIn
            )
        }
        .padding(.vertical, Spacing.extraSmall)
    }

    private func makeProfile(_ account: Account) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "person.crop.circle.fill")
                .font(Typography.display)
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

    private func makeRow(
        _ title: String,
        symbolName: String,
        detail: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            LabeledContent {
                if let detail {
                    Text(detail)
                }
            } label: {
                Label(title, systemImage: symbolName)
            }
        }
        .foregroundStyle(Palette.text.color)
    }
}
