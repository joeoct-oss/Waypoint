//
//  SearchModel.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// Search's view model (#282): a tapped result pushes the product itself, through a navigator its
// coordinator hands it, instead of reporting the tap. The navigator is the stack's, scoped to the
// shop (`scoped(to: ShopFlow.self)`), so the model can push only shop routes, which the compiler
// checks. It imports only `WaypointCore`, never SwiftUI, so a unit test drives it with a real
// router and no screen.
@MainActor
final class SearchModel {
    private let navigation: FlowNavigator<ShopFlow>

    init(navigation: FlowNavigator<ShopFlow>) {
        self.navigation = navigation
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
}
