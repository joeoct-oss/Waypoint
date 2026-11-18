//
//  LabShopRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// The small shop flow the Lab's view and view-model demos run: a product at the root, with the cart
// and the reviews pushed above it.
//
// Conformances:
// - `NavigationFlow`, so the demo's routes name it, its stack is declared for it, and a
//   `FlowNavigator<LabShopFlow>` refuses any other flow's route at compile time.
enum LabShopFlow: NavigationFlow { }

// The demo cart, pushed by Add to cart in every navigation style.
//
// Conformances:
// - `Route`, so the demo's stack router can push it and find its destination.
struct LabCartRoute: Route {
    typealias Flow = LabShopFlow
}

// The demo reviews, pushed by the product's view model once they load.
//
// Conformances:
// - `Route`, so the demo's stack router can push it and find its destination.
struct LabReviewsRoute: Route {
    typealias Flow = LabShopFlow
}

// The three ways a screen can navigate, which the Lab's Navigation style screen compares.
//
// Conformances:
// - `String` raw values, so each style has a stable name in accessibility identifiers.
// - `CaseIterable`, so the style picker lists every style from this one declaration.
// - `Identifiable`, so the demo cover can be presented for one style at a time.
enum NavigationStyle: String, CaseIterable, Identifiable {
    case outputs
    case navigator
    case wrappers

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .outputs:
            return "Outputs"
        case .navigator:
            return "Navigator"
        case .wrappers:
            return "Wrappers"
        }
    }

    // Who pushes the cart in this style, as the demo product's note says it.
    var pusher: String {
        switch self {
        case .outputs:
            return "Pushed by the coordinator"
        case .navigator:
            return "Pushed by ProductModel"
        case .wrappers:
            return "Pushed by @FlowNavigation"
        }
    }

    var explanation: String {
        switch self {
        case .outputs:
            return "The view reports Add to cart, and the coordinator that made it pushes."
        case .navigator:
            return "ProductModel holds a FlowNavigator<LabShopFlow>. A push of another flow's route does not compile."
        case .wrappers:
            return "The view reads the nearest LabShopFlow stack with @FlowNavigation and pushes itself."
        }
    }

    // The code the style needs, as the Navigation style screen shows it.
    var sample: String {
        switch self {
        case .outputs:
            return """
            // ProductView reports, the coordinator decides
            ProductView(onBuy: { self.showCart() })
            """
        case .navigator:
            return """
            // ProductModel, one flow only
            let navigation: FlowNavigator<LabShopFlow>
            func buy() {
                navigation.push(LabCartRoute())
            }
            """
        case .wrappers:
            return """
            // ProductView finds its own stack
            @FlowNavigation(LabShopFlow.self) private var shop
            Button("Add to cart") { shop.push(LabCartRoute()) }
            """
        }
    }
}
