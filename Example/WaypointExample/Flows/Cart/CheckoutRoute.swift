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

// The checkout flow's first screen, the address step, which the cart's router presents full
// screen. Checkout has three steps, address, payment and review, so the journey lines write
// `step 2 of 3`.
//
// Conformances:
// - `TrackableScreen`, so the cart's router can present it and the journey names it `Checkout` and
//   counts its steps.
struct CheckoutRoute: TrackableScreen {
    typealias Flow = CheckoutFlow

    static let stepsInFlow: Int? = 3
}

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

// The new-address form, pushed inside checkout from Add a new address. It sits beside the steps,
// so the journey doesn't count it as one.
//
// Conformances:
// - `TrackableScreen`, so checkout's stack router can push it and find its destination, and the
//   journey names it `New address` and leaves it out of the steps.
struct AddAddressRoute: TrackableScreen {
    typealias Flow = CheckoutFlow

    static let screenName = "New address"
    static let isFlowStep = false
}
