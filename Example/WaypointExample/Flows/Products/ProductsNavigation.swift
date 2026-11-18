//
//  ProductsNavigation.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// What a products stack needs from the app to navigate: the configuration its router gets, the log
// that shows navigation issues, and whether the product page draws its related link as a system
// `NavigationLink` instead of a `WaypointLink`, which only a UI test asks for.
struct ProductsNavigation {
    let configuration: NavigationConfiguration
    let issues: IssueLog
    let usesSystemLinks: Bool
}
