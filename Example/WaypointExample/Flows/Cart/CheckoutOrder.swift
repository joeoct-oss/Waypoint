//
//  CheckoutOrder.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The order checkout places: the cart's products, the address it goes to and the card that pays
// for it.
//
// Conformances:
// - `Equatable`, so a test can compare the order checkout placed.
struct CheckoutOrder: Equatable {
    let products: [Product]
    let address: Address
    let payment: PaymentCard
}

// A saved card checkout pays with. The example app has one, `saved`.
//
// Conformances:
// - `Equatable`, so an order's card can be compared.
nonisolated struct PaymentCard: Equatable {
    static let saved = PaymentCard(
        lastDigits: "4242",
        expiry: "08/29"
    )

    let lastDigits: String
    let expiry: String
}
