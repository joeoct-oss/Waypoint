//
//  CheckoutView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Checkout, presented full screen: delivery, payment and the total, with Place order and Cancel.
struct CheckoutView: View {
    let products: [Product]
    let onPlaceOrder: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            Section("Delivery") {
                LabeledContent("Address", value: "12 Orbit Road")
                LabeledContent("Arrives", value: "In 2 days")
            }
            Section("Payment") {
                LabeledContent("Card", value: "•••• 4242")
                LabeledContent("Total") {
                    Text(Product.total(of: products), format: .currency(code: "USD"))
                }
            }
        }
        .exampleForm()
        .toolbar { cancelItem }
        .bottomActionBar { placeOrderButton }
    }

    private var cancelItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "xmark", action: onCancel)
        }
    }

    private var placeOrderButton: some View {
        PrimaryActionButton(
            title: "Place order",
            identifier: Identifiers.placeOrder,
            action: onPlaceOrder
        )
        .disabled(products.isEmpty)
        .padding(Spacing.large)
    }
}
