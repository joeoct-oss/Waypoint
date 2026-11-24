//
//  ProductsDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// What Shop and Search use, from `AppServices.productsDependencies(gate:launch:)`: the catalog
// they list, the store that keeps the wish list, the window's account gate for Save, and the
// window's link settings for the products stacks.
struct ProductsDependencies {
    let catalog: any ProductCatalog
    let store: LocalStore
    let gate: any SheetAccountGating
    let navigation: ProductsNavigation
}
