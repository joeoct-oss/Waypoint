//
//  ProductsDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleServices
import ExampleStore
import SwiftUI

// What Shop and Search use, from `AppServices.productsDependencies(gate:launch:)`: the catalog
// they list, the store that keeps the wish list, the window's account gate for Save, and the
// window's link settings for the products stacks, and the Cart feature's cart screen, which Go to
// cart pushes on Shop. The app hands in the cart screen, so this feature never names Cart's types.
package struct ProductsDependencies {
    package let catalog: any ProductCatalog
    package let store: LocalStore
    package let gate: any SheetAccountGating
    package let navigation: ProductsNavigation
    package let cartScreen: (ShopCartScreen) -> AnyView

    package init(
        catalog: any ProductCatalog,
        store: LocalStore,
        gate: any SheetAccountGating,
        navigation: ProductsNavigation,
        cartScreen: @escaping (ShopCartScreen) -> AnyView
    ) {
        self.catalog = catalog
        self.store = store
        self.gate = gate
        self.navigation = navigation
        self.cartScreen = cartScreen
    }
}

// What the cart pushed on Shop shows, and what its two buttons do.
package struct ShopCartScreen {
    package let products: [Product]
    package let onCheckout: () -> Void
    package let onShopMore: () -> Void
}
