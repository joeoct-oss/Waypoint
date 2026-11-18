//
//  WishlistView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The wish list, as a small sheet that can grow: the products the reader saved, closed with Done.
struct WishlistView: View {
    let products: [Product]
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            list
                .navigationTitle("Wish list")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { doneItem }
        }
        .accessibilityIdentifier(Identifiers.wishlist)
        .presentationDetents(WishlistDetents.all)
    }

    private var list: some View {
        List(products) { product in
            LabeledContent(product.name) {
                Text(product.price, format: .currency(code: "USD"))
            }
        }
    }

    private var doneItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", action: onDone)
        }
    }
}

// The sizes the wish list sheet can take.
enum WishlistDetents {
    static var all: Set<PresentationDetent> {
        [
            .medium,
            .large,
        ]
    }
}
