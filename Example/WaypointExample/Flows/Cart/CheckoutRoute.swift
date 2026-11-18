//
//  CheckoutRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// Checkout: a flow of its own, whose stack starts at the address step.
//
// Conformances:
// - `NavigationFlow`, so checkout's routes name it and its stack is declared for it.
enum CheckoutFlow: NavigationFlow { }

// A checkout step pushed above the address step. The steps carry nothing: the cart coordinator
// keeps the cart and the chosen address.
//
// Conformances:
// - `Route`, so checkout's stack router can push it and find its destination.
enum CheckoutStep: Route {
    case payment
    case review

    typealias Flow = CheckoutFlow
}

// The new-address form, pushed inside checkout from Add a new address.
//
// Conformances:
// - `Route`, so checkout's stack router can push it and find its destination.
struct AddAddressRoute: Route {
    typealias Flow = CheckoutFlow
}
