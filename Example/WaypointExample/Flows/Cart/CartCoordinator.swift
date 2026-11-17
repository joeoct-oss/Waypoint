//
//  CartCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The cart tab: the cart at the root, and checkout presented full screen as its own flow. Placing the
// order ends checkout; Keep shopping reports to the main tabs, which open Shop.
//
// Conformances:
// - `Observable` (from `@Observable`), so `CartFlowView` redraws when checkout opens or closes.
@MainActor
@Observable
final class CartCoordinator {
    private static let trail = [
        "cart",
    ]
    private static let checkoutTrail = [
        "cart",
        "checkout",
    ]

    private let onShopMore: () -> Void
    // `var` because `showCheckout()` and `dismissCheckout()` change it, and `syncCheckout(_:)` takes the
    // system's own dismissal.
    private(set) var isCheckingOut: Bool

    init(onShopMore: @escaping () -> Void) {
        self.onShopMore = onShopMore
        isCheckingOut = false
    }

    func makeCartFlow() -> some View {
        CartView(
            products: Product.sampleCart,
            onCheckout: { self.showCheckout() },
            onShopMore: { self.showShop() }
        )
        .screenChrome(
            title: MainTab.cart.title,
            kind: nil,
            trail: Self.trail
        )
    }

    func makeCheckoutFlow() -> some View {
        NavigationStack {
            CheckoutView(
                onPlaceOrder: { self.dismissCheckout() },
                onCancel: { self.dismissCheckout() }
            )
            .screenChrome(
                title: "Checkout",
                kind: nil,
                trail: Self.checkoutTrail
            )
        }
    }

    func showCheckout() {
        isCheckingOut = true
    }

    func showShop() {
        onShopMore()
    }

    func dismissCheckout() {
        isCheckingOut = false
    }

    func syncCheckout(_ isShowing: Bool) {
        isCheckingOut = isShowing
    }
}

extension Product {
    // The two products every cart starts with, so checkout always has something to show.
    static var sampleCart: [Product] {
        Array(all.prefix(2))
    }
}
