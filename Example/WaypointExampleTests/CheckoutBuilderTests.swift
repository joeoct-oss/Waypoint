//
//  CheckoutBuilderTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
@testable import WaypointExample

// One checkout's draft (planning #424): the order it places has the cart's products, the chosen
// address and the card, placing it empties the cart, and with no address it can't be placed.
struct CheckoutBuilderTests {
    private static let lampID = 1
    private static let mugID = 2

    @Test
    func checkoutPlacesOrderWithChosenAddressAndPayment() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let checkout = makeCheckout(store: store)
        let work = try #require(Address.samples.last)

        checkout.selectAddress(work)
        let order = checkout.placeOrder()

        let expected = CheckoutOrder(
            products: SampleCatalog().products(withIDs: cartIDs()),
            address: work,
            payment: .saved
        )
        #expect(order == expected)
    }

    @Test
    func checkoutWithoutAddressCannotPlaceOrder() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        store.addresses = []
        let checkout = makeCheckout(store: store)

        let order = checkout.placeOrder()

        #expect(!checkout.canPlaceOrder)
        #expect(order == nil)
        #expect(store.cartProductIDs == cartIDs())
    }

    @Test
    func placedOrderEmptiesCart() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let checkout = makeCheckout(store: store)

        _ = checkout.placeOrder()

        #expect(store.cartProductIDs.isEmpty)
    }

    private func cartIDs() -> [Int] {
        [
            Self.lampID,
            Self.mugID,
        ]
    }

    private func makeCheckout(store: LocalStore) -> CheckoutBuilder {
        store.cartProductIDs = cartIDs()
        let dependencies = CartDependencies(
            catalog: SampleCatalog(),
            store: store,
            addresses: AddressBook(store: store),
            gate: FakeAccountGate(isSignedIn: true)
        )
        return CartFactory(dependencies: dependencies).makeCheckoutBuilder()
    }
}
