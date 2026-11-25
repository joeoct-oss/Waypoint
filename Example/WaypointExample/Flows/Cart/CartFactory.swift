//
//  CartFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleAddresses
import ExampleStore
import SwiftUI
import Waypoint

// Builds the Cart tab and checkout from `CartDependencies`: the tab's coordinator, the cart, a new
// checkout draft, the new address form and Order placed. The coordinator passes in what each
// screen reports, so navigation stays in the coordinator.
package struct CartFactory {
    private let dependencies: CartDependencies

    package init(dependencies: CartDependencies) {
        self.dependencies = dependencies
    }

    // The Cart tab. Waypoint makes its router, which the main tabs make the stack every tab
    // shares. Keep shopping runs `onShopMore`.
    package func makeCoordinator(onShopMore: @escaping () -> Void) -> CartCoordinator {
        CartCoordinator(
            dependencies: dependencies,
            factory: self,
            onShopMore: onShopMore
        )
    }

    package func makeCart(
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
    package func makeCheckoutBuilder() -> CheckoutBuilder {
        CheckoutBuilder(dependencies: dependencies)
    }

    package func makeAddAddress(onSave: @escaping (Address, Bool) -> Void) -> AddAddressView {
        AddAddressView(
            asksToKeep: true,
            onSave: onSave
        )
    }

    package func makeOrderPlaced(onContinueShopping: @escaping () -> Void) -> OrderPlacedView {
        OrderPlacedView(onContinueShopping: onContinueShopping)
    }
}
