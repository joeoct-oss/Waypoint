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
// leaves it `nil`. The journey lines name it `Product 3 "Orbit Lamp"`: its id, then the product's
// name.
//
// Conformances:
// - `TrackableScreen`, so a Waypoint stack router can push it and find its destination, and the
//   journey shows the product's name.
struct ProductRoute: TrackableScreen {
    static let publicLogFields: Set<String> = [
        "id",
    ]

    let id: Int

    @RouteHint
    var preview: Product?

    var screenDisplayName: String? {
        preview?.name ?? Product.find(id: id)?.name
    }
}

// The collection screen a products stack pushes from Shop's banner. Like `ProductRoute`, it carries
// the collection's id, and the banner hands the collection over as `preview`.
//
// Conformances:
// - `TrackableScreen`, so a Waypoint stack router can push it and find its destination, and the
//   journey shows the collection's name.
struct CollectionRoute: TrackableScreen {
    static let publicLogFields: Set<String> = [
        "id",
    ]

    let id: String

    @RouteHint
    var preview: ProductCollection?

    var screenDisplayName: String? {
        preview?.name ?? ProductCollection.find(id: id)?.name
    }
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

// The filters, presented as a sheet over the shop by the products router.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Filter".
struct FilterRoute: TrackableScreen {
    static let screenName = "Filter"
}

// The wish list, presented as a sheet over a product by the products router.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Wish list".
struct WishlistRoute: TrackableScreen {
    static let screenName = "Wish list"
}

// A sheet a products stack can present: the filters over the shop, or the wish list over a
// product. The sheet's router draws one of these until the sheet has slid away.
enum ProductSheet {
    case filters
    case wishlist
}
