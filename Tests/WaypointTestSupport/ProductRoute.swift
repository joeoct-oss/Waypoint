//
//  ProductRoute.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

/// A shared test route for a product detail screen, identified by the product it shows.
///
/// Conformances:
/// - `Route`, so it can be pushed, presented and saved in tests.
package struct ProductRoute: Route {
    /// The product identifier.
    package let id: Int

    /// Creates a product route for the given product.
    package init(id: Int) {
        self.id = id
    }
}
