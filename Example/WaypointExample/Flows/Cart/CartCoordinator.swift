//
//  CartCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import ExampleNavigation
import ExampleServices
import ExampleStore
import SwiftUI
import Waypoint

// The cart tab: the cart at the root, and checkout presented full screen as its own flow. Check out
// needs an account, so the account gate asks a guest to sign in first.
//
// Both run on Waypoint: the cart's router, which Waypoint makes and the main tabs make the one
// stack every tab shares, presents checkout full screen as a flow with a fresh router of its own
// each time, which `CheckoutCover` draws with `WaypointStack(flow: CheckoutFlow.self)`. So the
// journey lines write `flow_started Checkout from Cart`, each step with `step 2 of 3`, and
// `flow_finished`.
// `CartFactory` builds the cart and the forms, and each checkout gets a new `CheckoutBuilder`, its
// draft: it starts at the address step with the first saved address chosen; Continue pushes
// Payment, then Review, and Add a new address pushes the form. Saving the form pops back to the
// address step and chooses the new address; with Save for next time on, the address book keeps it
// for Account too. Placing the order empties the cart and replaces checkout's steps with Order
// placed in one change (`setPath`), so Back can't return to Review; Continue shopping there closes
// checkout and reports to the main tabs, which open Shop, as Keep shopping in the cart does. The
// local store keeps the cart between launches. The full-screen cover itself is still SwiftUI's,
// bound to the router's presented flow, until Waypoint draws presentations itself.
//
// Conformances:
// - `StackCoordinator`, so Waypoint makes its router and the main tabs make it the shared stack.
// - `Observable` (from `@Observable`), so the cart's root and the tab's badge redraw when the cart
//   or checkout changes.
@Observable
package final class CartCoordinator: StackCoordinator {
    private let store: LocalStore
    private let gate: any AccountGating
    private let factory: CartFactory
    private let onShopMore: () -> Void
    // `var` because `add(_:)` adds to it and `placeOrder()` empties it.
    package private(set) var products: [Product]
    // `var` because `showCheckout()` keeps the checkout flow's router that the cart's router
    // presents, and `releaseCheckout()` drops it once the cover has gone, so the cover still draws
    // checkout while it slides down.
    package private(set) var checkoutRouter: StackRouter?
    // `var` for the same reason as `checkoutRouter`: the open checkout's draft.
    package private(set) var checkout: CheckoutBuilder?

    // The tab's root: the cart.
    package var root: some View {
        makeCartFlow()
    }

    // Whether checkout is presented over the cart. Every tab shares one stack, so a sheet another
    // tab presents doesn't count.
    package var isCheckingOut: Bool {
        guard let checkoutRouter else {
            return false
        }
        return router.presented === checkoutRouter
    }

    // Checkout's router while checkout shows, else the cart's own, so a screen still drawing as the
    // cover slides down keeps a trail.
    private var checkoutStack: StackRouter {
        checkoutRouter ?? router
    }

    // The account gate's notice, such as "Signed in as" after a guest's Check out, which the
    // checkout cover would otherwise hide.
    package var accountNotice: Notice? {
        gate.notice
    }

    package init(
        dependencies: CartDependencies,
        factory: CartFactory,
        onShopMore: @escaping () -> Void
    ) {
        store = dependencies.store
        gate = dependencies.gate
        self.factory = factory
        self.onShopMore = onShopMore
        products = dependencies.catalog.products(withIDs: dependencies.store.cartProductIDs)
        checkoutRouter = nil
        checkout = nil
    }

    // Registers checkout, which this stack presents rather than pushes.
    package func registerDestinations(on router: StackRouter) {
        router.register(CheckoutRoute.self)
    }

    package func makeCartFlow() -> some View {
        factory.makeCart(
            products: products,
            onCheckout: { self.checkOut() },
            onShopMore: { self.showShop() }
        )
        .screenChrome(
            title: MainTab.cart.title,
            kind: nil,
            router: router,
            route: nil
        )
    }

    @ViewBuilder
    package func makeCheckoutFlow() -> some View {
        if let checkoutRouter, let checkout {
            WaypointStack(flow: CheckoutFlow.self, router: checkoutRouter) {
                makeAddressStepFlow(checkout)
                    .destination(CheckoutStep.self) { self.makeStepFlow(for: $0, in: checkout) }
                    .destination(AddAddressRoute.self) { _ in self.makeAddAddressFlow() }
                    .destination(OrderPlacedRoute.self) { _ in self.makeOrderPlacedFlow() }
            }
        }
    }

    @ViewBuilder
    package func makeStepFlow(
        for step: CheckoutStep,
        in checkout: CheckoutBuilder
    ) -> some View {
        switch step {
        case .payment:
            makePaymentStepFlow(checkout)
        case .review:
            makeReviewStepFlow(checkout)
        }
    }

    package func checkOut() {
        gate.requireAccount(for: .checkout) { self.showCheckout() }
    }

    // Opens checkout with a new draft from the cart.
    package func showCheckout() {
        let draft = factory.makeCheckoutBuilder()
        router.present(CheckoutRoute(), style: .fullScreenCover, trigger: "checkout_button")
        guard let presented = router.presented, presented !== checkoutRouter else {
            return
        }
        checkout = draft
        checkoutRouter = presented
    }

    package func showShop() {
        onShopMore()
    }

    package func showAddAddress() {
        checkout?.clearSavedNotice()
        checkoutRouter?.push(AddAddressRoute())
    }

    package func showPayment() {
        checkout?.clearSavedNotice()
        checkoutRouter?.push(CheckoutStep.payment)
    }

    package func showReview() {
        checkoutRouter?.push(CheckoutStep.review)
    }

    // Takes the form's result: the draft keeps and chooses the address, and checkout goes back to
    // the address step.
    package func addAddress(
        _ address: Address,
        keepsIt: Bool
    ) {
        checkout?.addAddress(address, keepsIt: keepsIt)
        checkoutRouter?.pop()
    }

    package func add(_ product: Product) {
        guard !products.contains(product) else {
            return
        }
        products.append(product)
        saveCart()
    }

    // Payment and Review leave the path in the same change that shows Order placed.
    package func placeOrder() {
        guard checkout?.placeOrder() != nil else {
            return
        }
        products = []
        checkoutRouter?.setPath {
            OrderPlacedRoute()
        }
    }

    package func continueShopping() {
        dismissCheckout()
        showShop()
    }

    package func dismissCheckout() {
        router.dismiss()
    }

    // Takes the system's own dismissal of the cover.
    package func syncCheckout(_ isShowing: Bool) {
        guard !isShowing else {
            return
        }
        dismissCheckout()
    }

    // Drops the checkout router and its draft once the cover has gone.
    package func releaseCheckout() {
        checkoutRouter = nil
        checkout = nil
    }

    private func makeAddressStepFlow(_ checkout: CheckoutBuilder) -> some View {
        checkout.makeAddressStep(
            onAddAddress: { self.showAddAddress() },
            onContinue: { self.showPayment() },
            onClose: { self.dismissCheckout() }
        )
        .screenChrome(
            title: "Checkout",
            kind: nil,
            router: checkoutStack,
            route: nil
        )
    }

    private func makePaymentStepFlow(_ checkout: CheckoutBuilder) -> some View {
        checkout.makePaymentStep(onContinue: { self.showReview() })
            .screenChrome(
                title: "Payment",
                kind: nil,
                router: checkoutStack,
                route: AnyRoute(CheckoutStep.payment)
            )
    }

    private func makeReviewStepFlow(_ checkout: CheckoutBuilder) -> some View {
        checkout.makeReview(onPlaceOrder: { self.placeOrder() })
            .screenChrome(
                title: "Review",
                kind: nil,
                router: checkoutStack,
                route: AnyRoute(CheckoutStep.review)
            )
    }

    private func makeAddAddressFlow() -> some View {
        factory.makeAddAddress(onSave: { self.addAddress($0, keepsIt: $1) })
            .screenChrome(
                title: "New address",
                kind: nil,
                router: checkoutStack,
                route: AnyRoute(AddAddressRoute())
            )
    }

    private func makeOrderPlacedFlow() -> some View {
        factory.makeOrderPlaced(onContinueShopping: { self.continueShopping() })
            .screenChrome(
                title: "Order placed",
                kind: nil,
                router: checkoutStack,
                route: AnyRoute(OrderPlacedRoute())
            )
    }

    private func saveCart() {
        store.cartProductIDs = products.map(\.id)
    }
}
