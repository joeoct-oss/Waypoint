//
//  CartView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The cart: its products and total, with Check out. The screen reports each choice.
struct CartView: View {
    let products: [Product]
    let onCheckout: () -> Void
    let onShopMore: () -> Void

    private var total: Decimal {
        products.reduce(0) { $0 + $1.price }
    }

    var body: some View {
        List {
            Section {
                ForEach(products) { product in
                    ProductRow(product: product) { onShopMore() }
                }
            }
            Section {
                LabeledContent("Total") {
                    Text(total, format: .currency(code: "USD"))
                }
                Button("Keep shopping", action: onShopMore)
            }
        }
        .exampleList()
        .safeAreaInset(edge: .bottom) { checkoutButton }
    }

    private var checkoutButton: some View {
        PrimaryActionButton(
            title: "Check out",
            identifier: "cart.checkout",
            action: onCheckout
        )
        .padding(Spacing.large)
    }
}
