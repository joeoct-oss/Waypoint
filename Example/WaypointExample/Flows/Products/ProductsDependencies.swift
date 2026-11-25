//
//  ProductsDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// What Shop and Search use, from `AppServices.productsDependencies(gate:launch:)`: the catalog
// they list, the store that keeps the wish list, the window's account gate for Save, and the
// window's link settings for the products stacks, and the Cart feature's cart screen, which Go to
// cart pushes on Shop. The app hands in the cart screen, so this feature never names Cart's types
// (planning #445).
struct ProductsDependencies {
    let catalog: any ProductCatalog
    let store: LocalStore
    let gate: any SheetAccountGating
    let navigation: ProductsNavigation
    let cartScreen: (ShopCartScreen) -> AnyView
}

// What the cart pushed on Shop shows, and what its two buttons do.
struct ShopCartScreen {
    let products: [Product]
    let onCheckout: () -> Void
    let onShopMore: () -> Void
}
