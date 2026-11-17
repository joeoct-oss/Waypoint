//
//  CheckoutView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Checkout, presented full screen: delivery and payment, with Place order and Cancel.
struct CheckoutView: View {
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
            }
        }
        .scrollContentBackground(.hidden)
        .toolbar { cancelItem }
        .safeAreaInset(edge: .bottom) { placeOrderButton }
    }

    private var cancelItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
        }
    }

    private var placeOrderButton: some View {
        PrimaryActionButton(
            title: "Place order",
            identifier: "checkout.placeOrder",
            action: onPlaceOrder
        )
        .padding(Spacing.large)
    }
}
