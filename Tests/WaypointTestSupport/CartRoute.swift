//
//  CartRoute.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

/// A shared test route for the cart, which belongs to the shop flow.
///
/// Conformances:
/// - `Route`, so it can be pushed, presented and saved in tests.
package struct CartRoute: Route {
    /// The shop flow, so only a shop navigator can push the cart.
    package typealias Flow = ShopFlow

    /// Creates the route.
    package init() {
        // No stored properties.
    }
}
