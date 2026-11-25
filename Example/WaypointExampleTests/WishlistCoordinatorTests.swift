//
//  WishlistCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Waypoint
@testable import WaypointExample

// The wish list, the child flow Shop presents (planning #462): a suggestion's Save asks a guest to
// sign in over the wish list and saves nothing yet, a signed-in reader's Save adds the product to
// the wish list the store keeps, and Done closes the flow, leaving nothing presented.
struct WishlistCoordinatorTests {
    private static let lampID = 1

    @Test
    func guestSaveSignsInOverTheWishlist() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let gate = FakeAccountGate(isSignedIn: false)
        let wishlist = TestProducts.makeFactory(store: store, gate: gate).makeWishlistFlow(onCloseAll: { })
        let lamp = try #require(Product.find(id: Self.lampID))

        wishlist.save(lamp)

        let expected: [SignInReason] = [
            .save,
        ]
        #expect(gate.reasons == expected)
        #expect(wishlist.productIDs.isEmpty)
        #expect(store.wishlistProductIDs.isEmpty)
    }

    @Test
    func signedInSaveAddsToTheWishlist() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let gate = FakeAccountGate(isSignedIn: true)
        let wishlist = TestProducts.makeFactory(store: store, gate: gate).makeWishlistFlow(onCloseAll: { })
        let lamp = try #require(Product.find(id: Self.lampID))

        wishlist.save(lamp)

        let expected = [
            Self.lampID,
        ]
        #expect(wishlist.productIDs == expected)
        #expect(store.wishlistProductIDs == expected)
    }

    @Test
    func doneClosesTheWishlist() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let gate = FakeAccountGate(isSignedIn: false)
        let wishlist = TestProducts.makeFactory(store: store, gate: gate).makeWishlistFlow(onCloseAll: { })
        let shop = StackRouter()
        let results = ResultLog<Void>()
        shop.present(wishlist) { result in
            results.record(result)
        }

        let presentedBeforeDone = shop.presented === wishlist.router
        wishlist.done()

        #expect(presentedBeforeDone)
        #expect(shop.presented == nil)
        #expect(results.values.count == 1)
    }
}
