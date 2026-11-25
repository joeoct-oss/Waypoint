//
//  TestProducts.swift
//  ExampleProductsTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleProducts
import ExampleServices
import ExampleStore
import SwiftUI

// A catalog of the products a test picks, so it knows exactly what the screens can list.
//
// Conformances:
// - `ProductCatalog`, so a feature lists it in place of the sample catalog.
struct FixedCatalog: ProductCatalog {
    let products: [Product]

    func product(id: Int) -> Product? {
        products.first { $0.id == id }
    }
}

// A products factory for a test, on its store, with its gate and catalog, and plain links.
enum TestProducts {
    static func makeFactory(
        store: LocalStore,
        gate: any SheetAccountGating,
        catalog: any ProductCatalog = SampleCatalog()
    ) -> ProductsFactory {
        let navigation = ProductsNavigation(
            configuration: NavigationConfiguration(),
            usesSystemLinks: false,
            linksToMissingDestination: false
        )
        let dependencies = ProductsDependencies(
            catalog: catalog,
            store: store,
            gate: gate,
            navigation: navigation,
            cartScreen: { _ in AnyView(EmptyView()) }
        )
        return ProductsFactory(dependencies: dependencies)
    }
}
