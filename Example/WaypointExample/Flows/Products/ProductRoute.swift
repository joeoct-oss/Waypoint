//
//  ProductRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// The product screen a products stack pushes. It carries the product's id, and the coordinator
// looks the product up, so the route stays small enough to compare, log and save. A list that
// already has the product hands it over as `preview` for the first frame; a link or a restore
// leaves it `nil`.
//
// Conformances:
// - `Route`, so a Waypoint stack router can push it and find its destination.
struct ProductRoute: Route {
    static let publicLogFields: Set<String> = [
        "id",
    ]

    let id: Int

    @RouteHint
    var preview: Product?
}

// The collection screen a products stack pushes from Shop's banner. Like `ProductRoute`, it carries
// the collection's id, and the banner hands the collection over as `preview`.
//
// Conformances:
// - `Route`, so a Waypoint stack router can push it and find its destination.
struct CollectionRoute: Route {
    static let publicLogFields: Set<String> = [
        "id",
    ]

    let id: String

    @RouteHint
    var preview: ProductCollection?
}

// A product's reviews. No screen in the products stacks draws it yet: only the `missingDestination`
// launch argument links to it, and lists it in the router's registry, so a UI test can check the
// screen a stack shows for a route with no destination of its own.
//
// Conformances:
// - `Route`, so the related link can push it onto a Waypoint stack.
struct ProductReviewsRoute: Route {
    static let publicLogFields: Set<String> = [
        "productID",
    ]

    let productID: Int
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
