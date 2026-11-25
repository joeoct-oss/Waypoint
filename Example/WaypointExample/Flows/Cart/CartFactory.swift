//
//  CartFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Builds the Cart tab and checkout from `CartDependencies`: the tab's coordinator, the cart, a new
// checkout draft, the new address form and Order placed. The coordinator passes in what each
// screen reports, so navigation stays in the coordinator.
struct CartFactory {
    private let dependencies: CartDependencies

    init(dependencies: CartDependencies) {
        self.dependencies = dependencies
    }

    // The Cart tab. Waypoint makes its router, which the main tabs make the stack every tab
    // shares. Keep shopping runs `onShopMore`.
    func makeCoordinator(onShopMore: @escaping () -> Void) -> CartCoordinator {
        CartCoordinator(
            dependencies: dependencies,
            factory: self,
            onShopMore: onShopMore
        )
    }

    func makeCart(
        products: [Product],
        onCheckout: @escaping () -> Void,
        onShopMore: @escaping () -> Void
    ) -> CartView {
        CartView(
            products: products,
            onCheckout: onCheckout,
            onShopMore: onShopMore
        )
    }

    // A new checkout, from the cart as the store keeps it now.
    func makeCheckoutBuilder() -> CheckoutBuilder {
        CheckoutBuilder(dependencies: dependencies)
    }

    func makeAddAddress(onSave: @escaping (Address, Bool) -> Void) -> AddAddressView {
        AddAddressView(
            asksToKeep: true,
            onSave: onSave
        )
    }

    func makeOrderPlaced(onContinueShopping: @escaping () -> Void) -> OrderPlacedView {
        OrderPlacedView(onContinueShopping: onContinueShopping)
    }
}
