//
//  CartCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// The cart tab: the cart at the root, and checkout presented full screen as its own flow. Check out
// needs an account, so the account gate asks a guest to sign in first.
//
// Both run on Waypoint: the cart's router is the one stack every main tab shares, and checkout is
// a flow that router presents full screen, with a fresh router of its own each time, which
// `CheckoutCover` draws with `WaypointStack(flow: CheckoutFlow.self)`. So the journey lines
// write `flow_started Checkout from Cart`, each step with `step 2 of 3`, and `flow_finished`. It
// starts at the address step with a saved address chosen; Continue pushes Payment, then Review,
// and Add a new address pushes the form. Saving the
// form pops back to the address step and chooses the new address; with Save for next time on, the
// address book keeps it for Account too. Placing the order empties the cart and replaces
// checkout's steps with Order placed in one change (`setPath`), so Back can't return to Review;
// Continue shopping there closes checkout and reports to the main tabs, which open Shop, as Keep
// shopping in the cart does. The local store keeps the cart between launches.
// The full-screen cover itself is still SwiftUI's, bound to the router's presented flow, until
// Waypoint draws presentations itself.
//
// Conformances:
// - `Observable` (from `@Observable`), so `CartFlowView` and the tab's badge redraw when the cart
//   or checkout changes.
@Observable
final class CartCoordinator {
    let router: StackRouter
    private let store: LocalStore
    private let addressBook: AddressBook
    private let gate: AccountGate
    private let onShopMore: () -> Void
    // `var` because `add(_:)` adds to it and `placeOrder()` empties it.
    private(set) var products: [Product]
    // `var` because `showCheckout()` keeps the checkout flow's router that the cart's router
    // presents, and `releaseCheckout()` drops it once the cover has gone, so the cover still draws
    // checkout while it slides down.
    private(set) var checkoutRouter: StackRouter?
    // `var` because `selectAddress(_:)` and `addAddress(_:keepsIt:)` change it, and
    // `showCheckout()` picks the first saved address.
    private(set) var selectedAddressID: String?
    // `var` because `addAddress(_:keepsIt:)` sets it for an address the reader didn't keep, and
    // `showCheckout()` clears it.
    private(set) var oneOffAddress: Address?
    // `var` because `addAddress(_:keepsIt:)` sets it, and choosing, continuing or a new checkout
    // clears it.
    private(set) var savedNotice: Address?

    // The addresses checkout offers: the saved ones, then one added for this order only.
    var checkoutAddresses: [Address] {
        guard let oneOffAddress else {
            return addressBook.addresses
        }
        return addressBook.addresses + CollectionOfOne(oneOffAddress)
    }

    var selectedAddress: Address? {
        checkoutAddresses.first { $0.id == selectedAddressID }
    }

    // Whether checkout is presented over the cart. Every tab shares one stack, so a sheet another
    // tab presents doesn't count.
    var isCheckingOut: Bool {
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
    var accountNotice: Notice? {
        gate.notice
    }

    init(
        router: StackRouter,
        store: LocalStore,
        addressBook: AddressBook,
        gate: AccountGate,
        onShopMore: @escaping () -> Void
    ) {
        self.router = router
        self.store = store
        self.addressBook = addressBook
        self.gate = gate
        self.onShopMore = onShopMore
        router.setRootName(MainTab.cart.title)
        router.register(CheckoutRoute.self)
        products = Product.products(withIDs: store.cartProductIDs)
        checkoutRouter = nil
        selectedAddressID = nil
        oneOffAddress = nil
        savedNotice = nil
        router.setCoordinator(self)
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
            router: router,
            route: nil
        )
    }

    @ViewBuilder
    func makeCheckoutFlow() -> some View {
        if let checkoutRouter {
            WaypointStack(flow: CheckoutFlow.self, router: checkoutRouter) {
                makeAddressStepFlow()
                    .destination(CheckoutStep.self) { self.makeStepFlow(for: $0) }
                    .destination(AddAddressRoute.self) { _ in self.makeAddAddressFlow() }
                    .destination(OrderPlacedRoute.self) { _ in self.makeOrderPlacedFlow() }
            }
        }
    }

    @ViewBuilder
    func makeStepFlow(for step: CheckoutStep) -> some View {
        switch step {
        case .payment:
            makePaymentStepFlow()
        case .review:
            makeReviewStepFlow()
        }
    }

    func checkOut() {
        gate.requireAccount(for: .checkout) { self.showCheckout() }
    }

    func showCheckout() {
        oneOffAddress = nil
        savedNotice = nil
        selectedAddressID = addressBook.addresses.first?.id
        router.present(CheckoutRoute(), style: .fullScreenCover, trigger: "checkout_button")
        checkoutRouter = router.presented
    }

    func showShop() {
        onShopMore()
    }

    func showAddAddress() {
        savedNotice = nil
        checkoutRouter?.push(AddAddressRoute())
    }

    func showPayment() {
        savedNotice = nil
        checkoutRouter?.push(CheckoutStep.payment)
    }

    func showReview() {
        checkoutRouter?.push(CheckoutStep.review)
    }

    func selectAddress(_ address: Address) {
        savedNotice = nil
        selectedAddressID = address.id
    }

    // Takes the form's result: keeps the address in the address book or for this order only,
    // chooses it, and goes back to the address step.
    func addAddress(_ address: Address, keepsIt: Bool) {
        if keepsIt {
            addressBook.add(address)
        } else {
            oneOffAddress = address
        }
        selectedAddressID = address.id
        savedNotice = address
        checkoutRouter?.pop()
    }

    func add(_ product: Product) {
        guard !products.contains(product) else {
            return
        }
        products.append(product)
        saveCart()
    }

    // Payment and Review leave the path in the same change that shows Order placed.
    func placeOrder() {
        products = []
        saveCart()
        checkoutRouter?.setPath {
            OrderPlacedRoute()
        }
    }

    func continueShopping() {
        dismissCheckout()
        showShop()
    }

    func dismissCheckout() {
        router.dismiss()
    }

    // Takes the system's own dismissal of the cover.
    func syncCheckout(_ isShowing: Bool) {
        guard !isShowing else {
            return
        }
        dismissCheckout()
    }

    // Drops the checkout router once the cover has gone.
    func releaseCheckout() {
        checkoutRouter = nil
    }

    private func makeAddressStepFlow() -> some View {
        CheckoutAddressView(
            addresses: checkoutAddresses,
            selectedID: selectedAddressID,
            savedNotice: savedNotice,
            onSelect: { self.selectAddress($0) },
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

    private func makePaymentStepFlow() -> some View {
        CheckoutPaymentView(onContinue: { self.showReview() })
            .screenChrome(
                title: "Payment",
                kind: nil,
                router: checkoutStack,
                route: AnyRoute(CheckoutStep.payment)
            )
    }

    private func makeReviewStepFlow() -> some View {
        CheckoutReviewView(
            products: products,
            address: selectedAddress,
            onPlaceOrder: { self.placeOrder() }
        )
        .screenChrome(
            title: "Review",
            kind: nil,
            router: checkoutStack,
            route: AnyRoute(CheckoutStep.review)
        )
    }

    private func makeAddAddressFlow() -> some View {
        AddAddressView(
            asksToKeep: true,
            onSave: { self.addAddress($0, keepsIt: $1) }
        )
        .screenChrome(
            title: "New address",
            kind: nil,
            router: checkoutStack,
            route: AnyRoute(AddAddressRoute())
        )
    }

    private func makeOrderPlacedFlow() -> some View {
        OrderPlacedView(onContinueShopping: { self.continueShopping() })
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
