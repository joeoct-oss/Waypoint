//
//  CartView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The cart: its products and total, with Check out. The screen reports each choice.
struct CartView: View {
    let products: [Product]
    let onCheckout: () -> Void
    let onShopMore: () -> Void

    var body: some View {
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
                LabeledContent("Total") {
                    Text(Product.total(of: products), format: .currency(code: "USD"))
                }
                Button("Keep shopping", action: onShopMore)
            }
        }
        .exampleList()
        .bottomActionBar { checkoutButton }
    }

    private var checkoutButton: some View {
        PrimaryActionButton(
            title: "Check out",
            identifier: Identifiers.checkout,
            action: onCheckout
        )
        .disabled(products.isEmpty)
        .padding(Spacing.large)
    }
}
