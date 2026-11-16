//
//  ProductRoute.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A shared test route for a product detail screen, identified by the product it shows.
package struct ProductRoute: Hashable, Sendable, Codable {
    /// The product identifier.
    package let id: Int

    /// Creates a product route for the given product.
    package init(id: Int) {
        self.id = id
    }
}
