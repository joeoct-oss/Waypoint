//
//  ProductRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// The product screen a products stack pushes. It carries only the product's id; the screen looks
// the product up, so the route stays small enough to compare, log and save.
//
// Conformances:
// - `Route`, so a Waypoint stack router can push it and find its destination.
struct ProductRoute: Route {
    static let publicLogFields: Set<String> = [
        "id",
    ]

    let id: Int
}

// Where a products stack starts: browsing the shop, or searching it.
enum ProductsStart {
    case browse
    case search
}

// A sheet a products stack can present: the filters over the shop, or the wish list over a product.
//
// Conformances:
// - `Identifiable`, so `.sheet(item:)` shows one sheet at a time and swaps them cleanly.
enum ProductSheet: Identifiable {
    case filters
    case wishlist

    var id: Self {
        self
    }
}
