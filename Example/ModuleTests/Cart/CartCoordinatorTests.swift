//
//  CartCoordinatorTests.swift
//  ExampleCartTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCart
import ExampleNavigation
import ExampleServices
import ExampleStore
import ExampleTestSupport
import Testing
import WaypointCore

// The Cart tab, built by `CartFactory` (planning #424): Check out asks a guest to sign in first,
// opens checkout at the address step for a signed-in reader, and each checkout starts from a new
// draft.
struct CartCoordinatorTests {
    private static let lampID = 1

    @Test("A guest's checkout asks to sign in first")
    func guestCheckoutAsksToSignInFirst() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let gate = FakeAccountGate(isSignedIn: false)
        let cart = makeCart(store: store, gate: gate)

        cart.checkOut()

        let expected: [SignInReason] = [
            .checkout,
        ]
        #expect(gate.reasons == expected)
        #expect(cart.router.presented == nil)
        #expect(cart.checkout == nil)
    }

    @Test("A signed-in checkout opens the address step")
    func signedInCheckoutOpensAddressStep() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let cart = makeCart(store: store, gate: FakeAccountGate(isSignedIn: true))

        cart.checkOut()

        #expect(cart.isCheckingOut)
        // The address step is checkout's root, so nothing is pushed above it.
        #expect(cart.checkoutRouter?.state.path.isEmpty == true)
        #expect(cart.checkout?.selectedAddress == Address.samples.first)
    }

    @Test("The checkout draft is dropped when checkout closes")
    func checkoutDraftIsDroppedWhenCheckoutCloses() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let cart = makeCart(store: store, gate: FakeAccountGate(isSignedIn: true))
        cart.checkOut()
        let oneOff = Address.new(
            label: "Studio",
            street: "9 Nebula Lane",
            city: "Springfield",
            postcode: "40333"
        )
        cart.checkout?.addAddress(oneOff, keepsIt: false)

        cart.dismissCheckout()
        cart.releaseCheckout()
        cart.checkOut()

        #expect(cart.checkout?.oneOffAddress == nil)
        #expect(cart.checkout?.selectedAddress == Address.samples.first)
    }

    private func makeCart(
        store: LocalStore,
        gate: FakeAccountGate
    ) -> CartCoordinator {
        store.cartProductIDs = [Self.lampID]
        let dependencies = CartDependencies(
            catalog: SampleCatalog(),
            store: store,
            addresses: AddressBook(store: store),
            gate: gate
        )
        return CartFactory(dependencies: dependencies).makeCoordinator(onShopMore: { })
    }
}
