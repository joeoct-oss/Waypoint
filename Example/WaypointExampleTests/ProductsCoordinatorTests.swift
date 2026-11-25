//
//  ProductsCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleServices
import ExampleStore
import Testing
import WaypointCore
@testable import WaypointExample

// Save on a product (planning #424): a guest is asked to sign in first and the wish list stays as
// it is, and a signed-in reader's Save adds the product to the wish list the store keeps.
struct ProductsCoordinatorTests {
    private static let lampID = 1

    @Test
    func guestSaveAsksToSignInFirst() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let gate = FakeAccountGate(isSignedIn: false)
        let shop = makeShop(store: store, gate: gate)
        let lamp = try #require(Product.find(id: Self.lampID))

        shop.save(lamp)

        let expected: [SignInReason] = [
            .save,
        ]
        #expect(gate.reasons == expected)
        #expect(store.wishlistProductIDs.isEmpty)
    }

    @Test
    func signedInSaveAddsToWishlist() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let shop = makeShop(store: store, gate: FakeAccountGate(isSignedIn: true))
        let lamp = try #require(Product.find(id: Self.lampID))

        shop.save(lamp)

        let expected = [
            Self.lampID,
        ]
        #expect(store.wishlistProductIDs == expected)
    }

    private func makeShop(
        store: LocalStore,
        gate: FakeAccountGate
    ) -> ProductsCoordinator {
        let cart = ProductsCart(
            products: { [] },
            onAddToCart: { _ in },
            onGoToCart: { },
            onCheckout: { }
        )
        return TestProducts.makeFactory(store: store, gate: gate).makeCoordinator(
            start: .browse(.none),
            cart: cart
        )
    }
}
