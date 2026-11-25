//
//  TestFactories.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleServices
import ExampleStore
import SwiftUI
import Waypoint
@testable import WaypointExample

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

// A Lab factory for a test: the sample catalog and the default navigation configuration.
enum TestLab {
    static func makeFactory() -> LabFactory {
        LabFactory(
            dependencies: LabDependencies(
                catalog: SampleCatalog(),
                navigation: .default
            )
        )
    }
}
