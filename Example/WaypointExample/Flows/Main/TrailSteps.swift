//
//  TrailSteps.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleAccount
import ExampleAuth
import ExampleCart
import ExampleLab
import ExampleNavigation
import ExampleProducts
import WaypointCore

// Every route the example app's trail names, which `AppWindow` puts in the environment for the
// screen chrome. A route left out reads by its type name.
enum TrailSteps {
    static let all: [any TrailStep.Type] = [
        ProductRoute.self,
        CollectionRoute.self,
        ShopCartRoute.self,
        FilterRoute.self,
        SavedRoute.self,
        WishlistRoute.self,
        CheckoutRoute.self,
        CheckoutStep.self,
        AddAddressRoute.self,
        OrderPlacedRoute.self,
        AccountRoute.self,
        CreateAccountRoute.self,
        TermsRoute.self,
        SignedInRoute.self,
        SheetDemoRoute.self,
        DetailProductRoute.self,
        DetailCartRoute.self,
    ]
}

// Conformances:
// - `TrailStep`, so the trail names the screen as the journey does.
extension ProductRoute: TrailStep { }
extension CollectionRoute: TrailStep { }
extension ShopCartRoute: TrailStep { }
extension FilterRoute: TrailStep { }
extension SavedRoute: TrailStep { }
extension WishlistRoute: TrailStep { }
extension CheckoutRoute: TrailStep { }
extension AddAddressRoute: TrailStep { }
extension OrderPlacedRoute: TrailStep { }
extension AccountRoute: TrailStep { }
extension CreateAccountRoute: TrailStep { }
extension TermsRoute: TrailStep { }
extension SignedInRoute: TrailStep { }
extension SheetDemoRoute: TrailStep { }

// Conformances:
// - `TrailStep`, so the trail names the step: `payment` or `review`.
extension CheckoutStep: TrailStep {
    var trailName: String {
        switch self {
        case .payment:
            return "payment"
        case .review:
            return "review"
        }
    }
}

// Conformances:
// - `TrailStep`, so the trail shows which product the Detail push story pushed.
extension DetailProductRoute: TrailStep {
    var trailName: String {
        "product \(productID)"
    }
}

// Conformances:
// - `TrailStep`, so the trail shows the cart the Detail push story pops back to.
extension DetailCartRoute: TrailStep {
    var trailName: String {
        "cart"
    }
}
