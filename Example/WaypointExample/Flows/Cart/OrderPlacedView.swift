//
//  OrderPlacedView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Order placed, shown in place of checkout once the order goes through, with Continue shopping. The
// screen reports Continue shopping, and the cart coordinator closes checkout and opens Shop.
struct OrderPlacedView: View {
    let onContinueShopping: () -> Void

    var body: some View {
        ContentUnavailableView(
            "Thanks for your order",
            systemImage: "checkmark.seal",
            description: Text("It arrives in 2 days. You can follow it in Account, under Orders.")
        )
        .accessibilityIdentifier(Identifiers.orderPlaced)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .bottomActionBar { continueButton }
    }

    private var continueButton: some View {
        PrimaryActionButton(
            title: "Continue shopping",
            identifier: Identifiers.continueShopping,
            action: onContinueShopping
        )
        .padding(Spacing.large)
    }
}
