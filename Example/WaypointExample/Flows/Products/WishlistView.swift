//
//  WishlistView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The wish list, as a small sheet that can grow: the saved products, closed with Done.
struct WishlistView: View {
    let products: [Product]
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List(products) { product in
                LabeledContent(product.name) {
                    Text(product.price, format: .currency(code: "USD"))
                }
            }
            .navigationTitle("Wish list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneItem }
        }
        .accessibilityIdentifier(Identifiers.wishlist)
        .presentationDetents(WishlistDetents.all)
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

extension Product {
    // The products every wish list starts with.
    static var sampleWishlist: [Product] {
        Array(all.suffix(3))
    }
}
