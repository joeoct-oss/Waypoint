//
//  CartCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint
import WaypointCore

// The cart tab: the cart at the root, and checkout presented full screen as its own flow. Check out
// needs an account, so the account gate asks a guest to sign in first.
//
// Both run on Waypoint: the cart's stack is the cart tab's router from the main tab router, and
// checkout is a flow that router presents full screen, with a fresh router of its own each time,
// which `CartFlowView` draws with `WaypointStack(flow: CheckoutFlow.self)`. So the journey lines
// write `flow_started Checkout from Cart`, each step with `step 2 of 3`, and `flow_finished`. It
// starts at the address step with a saved address chosen; Continue pushes Payment, then Review,
// and Add a new address pushes the form. Saving the
// form pops back to the address step and chooses the new address; with Save for next time on, the
// address book keeps it for Account too. Placing the order empties the cart and shows Order placed
// in place of checkout; Continue shopping there closes checkout and reports to the main tabs, which
// open Shop, as Keep shopping in the cart does. The local store keeps the cart between launches.
// The full-screen cover itself is still SwiftUI's, bound to the router's presented flow, until
// Waypoint draws presentations itself.
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

    let router: StackRouter
    private let store: LocalStore
    private let addressBook: AddressBook
    private let gate: AccountGate
    private let onShopMore: () -> Void
    // `var` because `add(_:)` adds to it and `placeOrder()` empties it.
    private(set) var products: [Product]
    // `var` because `placeOrder()` sets it, and `showCheckout()` clears it for the next order.
    private(set) var hasPlacedOrder: Bool
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

    // Whether checkout is presented over the cart.
    var isCheckingOut: Bool {
        router.presented != nil
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
        hasPlacedOrder = false
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
            trail: Self.trail
        )
    }

    @ViewBuilder
    func makeCheckoutFlow() -> some View {
        if hasPlacedOrder {
            NavigationStack {
                makeOrderPlacedFlow()
            }
        } else if let checkoutRouter {
            WaypointStack(flow: CheckoutFlow.self, router: checkoutRouter) {
                makeAddressStepFlow()
                    .destination(CheckoutStep.self) { self.makeStepFlow(for: $0) }
                    .destination(AddAddressRoute.self) { _ in self.makeAddAddressFlow() }
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
        gate.requireAccount { self.showCheckout() }
    }

    func showCheckout() {
        oneOffAddress = nil
        savedNotice = nil
        selectedAddressID = addressBook.addresses.first?.id
        hasPlacedOrder = false
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
            trail: Self.checkoutTrail + ["address"]
        )
    }

    private func makePaymentStepFlow() -> some View {
        CheckoutPaymentView(onContinue: { self.showReview() })
            .screenChrome(
                title: "Payment",
                kind: nil,
                trail: Self.checkoutTrail + ["payment"]
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
            trail: Self.checkoutTrail + ["review"]
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
            trail: Self.checkoutTrail + ["address", "new address"]
        )
    }

    private func makeOrderPlacedFlow() -> some View {
        OrderPlacedView(onContinueShopping: { self.continueShopping() })
            .screenChrome(
                title: "Order placed",
                kind: nil,
                trail: Self.checkoutTrail + ["order placed"]
            )
    }

    private func saveCart() {
        store.cartProductIDs = products.map(\.id)
    }
}
