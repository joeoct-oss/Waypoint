//
//  SearchModel.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleStore
import Foundation
import WaypointCore

// Search's view model (planning #417): a tapped result pushes the product itself, through a
// navigator its coordinator hands it, instead of reporting the tap. The navigator is the stack's,
// scoped to the shop (`scoped(to: ShopFlow.self)`), so the model can push only shop routes, which
// the compiler checks. It also finds the results in the catalog it is given, and lists the
// catalog's categories. It imports only `WaypointCore`, never SwiftUI, so a unit test drives it
// with a real router and no screen. `onShopStack(_:catalog:)` is the one place that wires it:
// `ProductsFactory` calls it for the coordinator and the unit tests.
final class SearchModel {
    private let navigation: FlowNavigator<ShopFlow>
    private let catalog: any ProductCatalog

    // Every category in the catalog, once each, in the catalog's order.
    var categories: [String] {
        catalog.products.reduce(into: [String]()) { categories, product in
            if !categories.contains(product.category) {
                categories.append(product.category)
            }
        }
    }

    init(
        navigation: FlowNavigator<ShopFlow>,
        catalog: any ProductCatalog
    ) {
        self.navigation = navigation
        self.catalog = catalog
    }

    // Declares the shop on the stack, then scopes the stack's navigator to it. Call it before
    // anything is pushed, so the navigator belongs to the root screen and lives as long as the
    // stack.
    static func onShopStack(
        _ router: StackRouter,
        catalog: any ProductCatalog
    ) -> SearchModel {
        router.declareFlow(ShopFlow.self)
        return SearchModel(
            navigation: router.navigator.scoped(to: ShopFlow.self),
            catalog: catalog
        )
    }

    // The products whose name or category holds every word of `query`, in the catalog's order.
    func results(for query: String) -> [Product] {
        let words = query.split(separator: " ").map(String.init)
        return catalog.products.filter { product in
            words.allSatisfy { Self.product(product, matches: $0) }
        }
    }

    // Pushes the product, handing it over for the first frame.
    @discardableResult
    func select(_ product: Product) -> NavigationOutcome {
        let route = ProductRoute(
            id: product.id,
            preview: product
        )
        return navigation.push(route)
    }

    private static func product(
        _ product: Product,
        matches word: String
    ) -> Bool {
        product.name.localizedCaseInsensitiveContains(word)
            || product.category.localizedCaseInsensitiveContains(word)
    }
}
