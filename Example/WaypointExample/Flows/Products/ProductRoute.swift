//
//  ProductRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleStore
import WaypointCore

// The shop: the products stacks of Shop and Search, which each declare it, so a view model's
// navigator scoped to it takes only the shop's routes.
//
// Conformances:
// - `NavigationFlow`, so `ProductRoute` names it and a navigator can be scoped to it.
package enum ShopFlow: NavigationFlow { }

// The product screen a products stack pushes. It carries the product's id, and the coordinator
// looks the product up, so the route stays small enough to compare, log and save. A list that
// already has the product hands it over as `preview` for the first frame; a link or a restore
// leaves it `nil`. The journey lines name it `Product 3 "Orbit Lamp"`: its id, then the product's
// name. It belongs to the shop, so a navigator scoped to `ShopFlow` can push it.
//
// Conformances:
// - `TrackableScreen`, so a Waypoint stack router can push it and find its destination, and the
//   journey shows the product's name.
package struct ProductRoute: TrackableScreen {
    package typealias Flow = ShopFlow

    package static let publicLogFields: Set<String> = [
        "id",
    ]

    package let id: Int

    @RouteHint
    package var preview: Product?

    package init(
        id: Int,
        preview: Product?
    ) {
        self.id = id
        self.preview = preview
    }

    package var screenDisplayName: String? {
        preview?.name ?? Product.find(id: id)?.name
    }
}

// The collection screen a products stack pushes from Shop's banner. Like `ProductRoute`, it carries
// the collection's id, and the banner hands the collection over as `preview`.
//
// Conformances:
// - `TrackableScreen`, so a Waypoint stack router can push it and find its destination, and the
//   journey shows the collection's name.
package struct CollectionRoute: TrackableScreen {
    package static let publicLogFields: Set<String> = [
        "id",
    ]

    package let id: String

    @RouteHint
    package var preview: ProductCollection?

    package var screenDisplayName: String? {
        preview?.name ?? ProductCollection.find(id: id)?.name
    }
}

// A product's reviews. No screen in the products stacks draws it yet: only the `missingDestination`
// launch argument links to it, and lists it in the router's registry, so a UI test can check the
// screen a stack shows for a route with no destination of its own.
//
// Conformances:
// - `Route`, so the related link can push it onto a Waypoint stack.
package struct ProductReviewsRoute: Route {
    package static let publicLogFields: Set<String> = [
        "productID",
    ]

    package let productID: Int
}

// Where a products stack starts: browsing the shop, which first plays the launch's product steps,
// or searching it.
package enum ProductsStart {
    case browse(ShopLaunchSteps)
    case search
}

extension ProductsStart {
    // The product steps Shop plays the first time it appears; Search plays none.
    package var launchSteps: ShopLaunchSteps {
        switch self {
        case .browse(let steps):
            return steps
        case .search:
            return .none
        }
    }

    // Names the stack's first screen in the journey lines.
    package var rootName: String {
        switch self {
        case .browse:
            return "Product list"
        case .search:
            return "Search"
        }
    }
}

// The cart, pushed above a product on Shop by Go to cart, so Back goes to the product. It shows the
// Cart tab's products.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Cart".
package struct ShopCartRoute: TrackableScreen {
    package init() { }

    package static let screenName = "Cart"
}

// The filters, presented as a sheet over the shop by the products router.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Filter".
package struct FilterRoute: TrackableScreen {
    package static let screenName = "Filter"
}

// The wish list's name in the journey and the trail. The wish list itself is the flow
// `WishlistCoordinator` runs, whose root is named after this route.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Wish list".
package struct WishlistRoute: TrackableScreen {
    package static let screenName = "Wish list"
}

// The small "Saved to your wish list" sheet, presented over a product by Save.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Saved".
package struct SavedRoute: TrackableScreen {
    package static let screenName = "Saved"
}

// A sheet a products stack can present: the filters over the shop, or, over a product, the saved
// sheet and the wish list that replaces it. The sheet's router draws one of these until the sheet
// has slid away.
package enum ProductSheet {
    case filters
    case saved
    case wishlist
}
