//
//  ProductsNavigation.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// What a products stack needs from the app to navigate: the configuration its router gets, whether
// the product page draws its related link as a system `NavigationLink` instead of a
// `WaypointLink`, and whether that link pushes a route with no destination in the stack. Only UI
// tests ask for the last two.
package struct ProductsNavigation {
    package let configuration: NavigationConfiguration
    package let usesSystemLinks: Bool
    package let linksToMissingDestination: Bool

    package init(
        configuration: NavigationConfiguration,
        usesSystemLinks: Bool,
        linksToMissingDestination: Bool
    ) {
        self.configuration = configuration
        self.usesSystemLinks = usesSystemLinks
        self.linksToMissingDestination = linksToMissingDestination
    }
}
