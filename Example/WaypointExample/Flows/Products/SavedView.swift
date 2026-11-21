//
//  SavedView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The small sheet Save shows over a product (MA-01): "Saved to your wish list", with View wish list
// and Close, which the sheet only reports. It is only as tall as its content.
struct SavedView: View {
    let onViewWishlist: () -> Void
    let onClose: () -> Void

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
        .presentationDetents(SavedDetents.all)
    }

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: onClose)
        }
    }
}

// The one size the saved sheet takes: just its content.
enum SavedDetents {
    private static let height: CGFloat = 240

    static var all: Set<PresentationDetent> {
        [
            .height(height),
        ]
    }
}
