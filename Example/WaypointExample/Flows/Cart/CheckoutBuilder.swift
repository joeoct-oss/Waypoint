//
//  CheckoutBuilder.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import ExampleStore
import SwiftUI

// One checkout's draft: the cart's products when it opened, the address chosen for this order, an
// address added for this order only, and the card. It builds each step's screen from that draft,
// and places the order, which empties the cart in the store. The cart coordinator makes one when
// checkout opens and drops it when checkout has closed, so the next checkout starts again from the
// first saved address.
//
// Conformances:
// - `Observable` (from `@Observable`), so the steps redraw when an address is chosen or added.
@Observable
package final class CheckoutBuilder {
    package let products: [Product]
    package let payment: PaymentCard
    private let store: LocalStore
    private let addressBook: AddressBook
    // `var` because `selectAddress(_:)` and `addAddress(_:keepsIt:)` change it. It starts at the
    // first saved address.
    package private(set) var selectedAddressID: String?
    // `var` because `addAddress(_:keepsIt:)` sets it for an address the reader didn't keep.
    package private(set) var oneOffAddress: Address?
    // `var` because `addAddress(_:keepsIt:)` sets it, and choosing or continuing clears it.
    package private(set) var savedNotice: Address?

    // The addresses checkout offers: the saved ones, then one added for this order only.
    package var addresses: [Address] {
        guard let oneOffAddress else {
            return addressBook.addresses
        }
        return addressBook.addresses + CollectionOfOne(oneOffAddress)
    }

    package var selectedAddress: Address? {
        addresses.first { $0.id == selectedAddressID }
    }

    // Whether the order can be placed: the cart has products and an address is chosen.
    package var canPlaceOrder: Bool {
        !products.isEmpty && selectedAddress != nil
    }

    package init(dependencies: CartDependencies) {
        products = dependencies.catalog.products(withIDs: dependencies.store.cartProductIDs)
        payment = .saved
        store = dependencies.store
        addressBook = dependencies.addresses
        selectedAddressID = dependencies.addresses.addresses.first?.id
        oneOffAddress = nil
        savedNotice = nil
    }

    package func makeAddressStep(
        onAddAddress: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) -> CheckoutAddressView {
        CheckoutAddressView(
            addresses: addresses,
            selectedID: selectedAddressID,
            savedNotice: savedNotice,
            onSelect: { self.selectAddress($0) },
            onAddAddress: onAddAddress,
            onContinue: onContinue,
            onClose: onClose
        )
    }

    package func makePaymentStep(onContinue: @escaping () -> Void) -> CheckoutPaymentView {
        CheckoutPaymentView(onContinue: onContinue)
    }

    package func makeReview(onPlaceOrder: @escaping () -> Void) -> CheckoutReviewView {
        CheckoutReviewView(
            products: products,
            address: selectedAddress,
            onPlaceOrder: onPlaceOrder
        )
    }

    package func selectAddress(_ address: Address) {
        savedNotice = nil
        selectedAddressID = address.id
    }

    // Takes the new address form's result: keeps the address in the address book or for this
    // order only, and chooses it.
    package func addAddress(
        _ address: Address,
        keepsIt: Bool
    ) {
        if keepsIt {
            addressBook.add(address)
        } else {
            oneOffAddress = address
        }
        selectedAddressID = address.id
        savedNotice = address
    }

    package func clearSavedNotice() {
        savedNotice = nil
    }

    // Places the order and empties the cart in the store, or returns `nil` when it can't be placed.
    package func placeOrder() -> CheckoutOrder? {
        guard canPlaceOrder, let selectedAddress else {
            return nil
        }
        store.cartProductIDs = []
        return CheckoutOrder(
            products: products,
            address: selectedAddress,
            payment: payment
        )
    }
}
