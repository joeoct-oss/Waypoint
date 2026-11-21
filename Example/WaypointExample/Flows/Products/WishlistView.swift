//
//  WishlistView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The wish list: the products the reader saved. As a sheet over a product it can grow and closes
// with Done; pushed from Account it has no Done.
struct WishlistView: View {
    let products: [Product]
    let onDone: (() -> Void)?

    var body: some View {
        list
            .navigationTitle("Wish list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneItem }
            .accessibilityIdentifier(Identifiers.wishlist)
    }

    private var list: some View {
        List(products) { product in
            makeRow(for: product)
        }
    }

    private var doneItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if let onDone {
                Button("Done", action: onDone)
            }
        }
    }

    private func makeRow(for product: Product) -> some View {
        HStack(spacing: Spacing.medium) {
            ProductIllustration(artwork: product.artwork, drawsBackdrop: true)
                .frame(width: Size.rowIcon, height: Size.rowIcon)
                .clipShape(RoundedRectangle(cornerRadius: Radius.field))
            LabeledContent(product.name) {
                Text(product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
            }
        }
    }
}
