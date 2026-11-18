//
//  UnscopedRouteOnScopedNavigator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must not compile: a shop navigator refuses a route of no flow; `shop.unscoped` takes it
// (#25, decision 0004).
// expected-error: requires the types 'ShopFlow' and 'AnyFlow' be equivalent

import WaypointCore

// Conformances:
// - `NavigationFlow`, so routes can name it as their flow.
enum ShopFlow: NavigationFlow { }

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct HelpRoute: Route { }

@MainActor
func showHelp(from shop: FlowNavigator<ShopFlow>) {
    shop.push(HelpRoute())
}
