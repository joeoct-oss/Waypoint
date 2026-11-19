//
//  ProductsNavigation.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// What a products stack needs from the app to navigate: the configuration its router gets, the log
// that shows navigation issues, whether the product page draws its related link as a system
// `NavigationLink` instead of a `WaypointLink`, and whether that link pushes a route with no
// destination in the stack. Only UI tests ask for the last two.
struct ProductsNavigation {
    let configuration: NavigationConfiguration
    let issues: IssueLog
    let usesSystemLinks: Bool
    let linksToMissingDestination: Bool
}
