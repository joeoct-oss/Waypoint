//
//  SavedView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// The small sheet Save shows over a product (MA-01): "Saved to your wish list", with View wish list,
// which the sheet reports, and Close. Close needs no coordinator: `@DismissFlow` closes the flow the
// view is in, the saved sheet, through the router that presented it. The router sizes the sheet to
// its content (`AppSheets.saved`).
struct SavedView: View {
    let onViewWishlist: () -> Void

    // `var` because a property wrapper needs one; it reads the sheet's router from the stack.
    @DismissFlow private var dismissFlow

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "heart.fill")
                .font(Typography.display)
                .foregroundStyle(Palette.accent.color)
                .accessibilityHidden(true)
            Text("Saved to your wish list")
                .font(Typography.headline)
                .foregroundStyle(Palette.text.color)
            PrimaryActionButton(
                title: "View wish list",
                identifier: Identifiers.viewWishlist,
                action: onViewWishlist
            )
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity)
        .navigationTitle("Wish list")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeItem }
        // Contains its children, so View wish list keeps its own identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Identifiers.savedSheet)
    }

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { dismissFlow() }
                .accessibilityIdentifier(Identifiers.savedClose)
        }
    }
}
