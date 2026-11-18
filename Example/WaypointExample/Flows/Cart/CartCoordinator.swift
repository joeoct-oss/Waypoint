//
//  CartCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The cart tab: the cart at the root, and checkout presented full screen as its own flow. Check out
// needs an account, so the account gate asks a guest to sign in first. Placing the order empties
// the cart and shows Order placed in place of checkout; Continue shopping there closes checkout and
// reports to the main tabs, which open Shop, as Keep shopping in the cart does. The local store
// keeps the cart between launches.
//
// Conformances:
// - `Observable` (from `@Observable`), so `CartFlowView` and the tab's badge redraw when the cart
//   or checkout changes.
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
    private static let orderPlacedTrail = [
        "cart",
        "checkout",
        "order placed",
    ]

    private let store: LocalStore
    private let gate: AccountGate
    private let onShopMore: () -> Void
    // `var` because `add(_:)` adds to it and `placeOrder()` empties it.
    private(set) var products: [Product]
    // `var` because `showCheckout()` and `dismissCheckout()` change it, and `syncCheckout(_:)`
    // takes the system's own dismissal.
    private(set) var isCheckingOut: Bool
    // `var` because `placeOrder()` sets it, and `showCheckout()` clears it for the next order.
    private(set) var hasPlacedOrder: Bool

    init(
        store: LocalStore,
        gate: AccountGate,
        onShopMore: @escaping () -> Void
    ) {
        self.store = store
        self.gate = gate
        self.onShopMore = onShopMore
        products = Product.products(withIDs: store.cartProductIDs)
        isCheckingOut = false
        hasPlacedOrder = false
    }

    func makeCartFlow() -> some View {
        CartView(
            products: products,
            onCheckout: { self.checkOut() },
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
            makeCheckoutScreen()
        }
    }

    func checkOut() {
        gate.requireAccount { self.showCheckout() }
    }

    func showCheckout() {
        hasPlacedOrder = false
        isCheckingOut = true
    }

    func showShop() {
        onShopMore()
    }

    func add(_ product: Product) {
        guard !products.contains(product) else {
            return
        }
        products.append(product)
        saveCart()
    }

    func placeOrder() {
        products = []
        saveCart()
        hasPlacedOrder = true
    }

    func continueShopping() {
        dismissCheckout()
        showShop()
    }

    func dismissCheckout() {
        isCheckingOut = false
    }

    func syncCheckout(_ isShowing: Bool) {
        isCheckingOut = isShowing
    }

    @ViewBuilder
    private func makeCheckoutScreen() -> some View {
        if hasPlacedOrder {
            makeOrderPlacedFlow()
        } else {
            makeCheckoutFormFlow()
        }
    }

    private func makeCheckoutFormFlow() -> some View {
        CheckoutView(
            products: products,
            onPlaceOrder: { self.placeOrder() },
            onCancel: { self.dismissCheckout() }
        )
        .screenChrome(
            title: "Checkout",
            kind: nil,
            trail: Self.checkoutTrail
        )
    }

    private func saveCart() {
        store.cartProductIDs = products.map(\.id)
    }

    private func makeOrderPlacedFlow() -> some View {
        OrderPlacedView(onContinueShopping: { self.continueShopping() })
            .screenChrome(
                title: "Order placed",
                kind: nil,
                trail: Self.orderPlacedTrail
            )
    }
}
