//
//  WishlistCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// The wish list, the child flow Shop presents as a sheet (planning #462): the products the store
// keeps, and up to three suggestions under "You may also like". A suggestion's Save asks a guest to
// sign in over the wish list, two sheets deep, and Done on Signed in reports `onCloseAll`, which
// closes both in one change. Done closes the flow through its own router (`dismissFlow`), which
// Shop gets as `.cancelled`; the flow has no result of its own.
//
// The sheet itself is still SwiftUI's, drawn by Shop, until Waypoint draws presented flows.
//
// Conformances:
// - `FlowCoordinator`, so Shop presents it with `present(_:style:trigger:else:onFinish:)` and
//   Waypoint makes its router inside Shop's tree.
// - `Observable` (from `@Observable`), so the wish list redraws when Save adds a product.
@Observable
final class WishlistCoordinator: FlowCoordinator {
    // The wish list finishes with nothing: Done and a swipe both just close it.
    typealias Output = Void

    private let factory: ProductsFactory
    private let onCloseAll: () -> Void
    // `var` because Save adds a product; it copies the local store, which nothing observes, so the
    // open wish list redraws. Only `keep(_:)` changes it.
    private(set) var productIDs: [Int]

    // The journey's name for the flow's only screen.
    var rootName: String {
        WishlistRoute.screenName
    }

    var root: some View {
        factory.makeWishlist(
            productIDs: productIDs,
            onSave: { self.save($0) },
            onDone: { self.done() }
        )
    }

    // `ProductsFactory` makes it, hands it the store and the account gate, and builds its screen.
    // Done on Signed in runs `onCloseAll`.
    init(
        factory: ProductsFactory,
        onCloseAll: @escaping () -> Void
    ) {
        self.factory = factory
        self.onCloseAll = onCloseAll
        productIDs = factory.dependencies.store.wishlistProductIDs
    }

    // Save under "You may also like": a guest signs in over the wish list first.
    func save(_ product: Product) {
        factory.dependencies.gate.requireAccount(
            for: .save,
            over: router,
            then: { self.keep(product) },
            done: { self.onCloseAll() }
        )
    }

    // Done: the wish list's own router asks the stack that presented it to close it.
    func done() {
        router.dismissFlow()
    }

    private func keep(_ product: Product) {
        let store = factory.dependencies.store
        if !store.wishlistProductIDs.contains(product.id) {
            store.wishlistProductIDs.append(product.id)
        }
        productIDs = store.wishlistProductIDs
    }
}
