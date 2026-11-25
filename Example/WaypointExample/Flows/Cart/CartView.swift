//
//  CartView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// The cart (MA-02): its products, the subtotal, shipping and total, with Check out at the bottom.
// An empty cart says so and offers Browse the shop instead. The screen reports each choice.
struct CartView: View {
    let products: [Product]
    let onCheckout: () -> Void
    let onShopMore: () -> Void

    var body: some View {
        if products.isEmpty {
            emptyState
        } else {
            contents
        }
    }

    private var contents: some View {
        List {
            Section {
                ForEach(products) { product in
                    ProductRow(
                        product: product,
                        detail: "Qty 1",
                        onSelect: onShopMore
                    )
                }
            }
            Section {
                makePriceLine("Subtotal", amount: Product.total(of: products))
                LabeledContent("Shipping", value: "Free")
                makePriceLine("Total", amount: Product.total(of: products))
                    .font(Typography.headline)
                Button("Keep shopping", action: onShopMore)
            }
        }
        .exampleList()
        .bottomActionBar { checkoutButton }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your cart is empty", systemImage: "cart")
        } description: {
            Text("Products you add show up here.")
        } actions: {
            Button("Browse the shop", action: onShopMore)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.brand.color)
                .accessibilityIdentifier(Identifiers.browseShop)
        }
        .background(Palette.background.color)
        // Contains its children, so Browse the shop keeps its own identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Identifiers.cartEmpty)
    }

    private var checkoutButton: some View {
        PrimaryActionButton(
            title: "Check out",
            identifier: Identifiers.checkout,
            action: onCheckout
        )
        .padding(Spacing.large)
    }

    private func makePriceLine(_ title: String, amount: Decimal) -> some View {
        LabeledContent(title) {
            Text(amount, format: .currency(code: "USD"))
        }
    }
}
