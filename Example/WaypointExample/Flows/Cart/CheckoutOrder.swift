//
//  CheckoutOrder.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleStore

// The order checkout places: the cart's products, the address it goes to and the card that pays
// for it.
//
// Conformances:
// - `Equatable`, so a test can compare the order checkout placed.
package struct CheckoutOrder: Equatable {
    package let products: [Product]
    package let address: Address
    package let payment: PaymentCard

    package init(
        products: [Product],
        address: Address,
        payment: PaymentCard
    ) {
        self.products = products
        self.address = address
        self.payment = payment
    }
}

// A saved card checkout pays with. The example app has one, `saved`.
//
// Conformances:
// - `Equatable`, so an order's card can be compared.
package nonisolated struct PaymentCard: Equatable {
    package static let saved = PaymentCard(
        lastDigits: "4242",
        expiry: "08/29"
    )

    package let lastDigits: String
    package let expiry: String
}
