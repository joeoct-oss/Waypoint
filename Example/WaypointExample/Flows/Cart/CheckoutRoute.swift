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
package enum CheckoutFlow: NavigationFlow { }

// The checkout flow's first screen, the address step, which the cart's router presents full
// screen. Checkout has three steps, address, payment and review, so the journey lines write
// `step 2 of 3`.
//
// Conformances:
// - `TrackableScreen`, so the cart's router can present it and the journey names it `Checkout` and
//   counts its steps.
package struct CheckoutRoute: TrackableScreen {
    package typealias Flow = CheckoutFlow

    package static let stepsInFlow: Int? = 3
}

// A checkout step pushed above the address step. The steps carry nothing: the cart coordinator
// keeps the cart and the chosen address.
//
// Conformances:
// - `Route`, so checkout's stack router can push it and find its destination.
package enum CheckoutStep: Route {
    case payment
    case review

    package typealias Flow = CheckoutFlow
}

// Order placed, which replaces checkout's steps once the order goes through, so Back can't return
// to Review. It ends the flow rather than counting as a step.
//
// Conformances:
// - `TrackableScreen`, so checkout's stack router can set it as its path and the journey names it
//   `Order placed`, outside the steps.
package struct OrderPlacedRoute: TrackableScreen {
    package typealias Flow = CheckoutFlow

    package static let screenName = "Order placed"
    package static let isFlowStep = false
}

// The new-address form, pushed inside checkout from Add a new address. It sits beside the steps,
// so the journey doesn't count it as one.
//
// Conformances:
// - `TrackableScreen`, so checkout's stack router can push it and find its destination, and the
//   journey names it `New address` and leaves it out of the steps.
package struct AddAddressRoute: TrackableScreen {
    package typealias Flow = CheckoutFlow

    package static let screenName = "New address"
    package static let isFlowStep = false
}
