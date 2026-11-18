//
//  ProductsCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import WaypointCore

// A stack of products: the shop or search at the root and a product pushed above it, with the
// filters and the wish list as sheets. Add to cart reports to the main tabs, which add the product
// to the cart and open Cart; a guest's Sign in reports to the app coordinator, which switches to
// the accounts flow.
//
// The stack runs on Waypoint: `router` owns the path, `ProductsFlowView` draws it with
// `WaypointStack`, and a swipe back comes back to the router by itself. The sheets are still plain
// SwiftUI state until Waypoint's sheets are built.
//
// Conformances:
// - `Observable` (from `@Observable`), so `ProductsFlowView` redraws when the sheet changes.
@MainActor
@Observable
final class ProductsCoordinator {
    private static let followUpDelay = Duration.milliseconds(150)
    private static let linkedProductID = 4

    let router: StackRouter
    private let start: ProductsStart
    private let membership: Membership
    private let launchSteps: ShopLaunchSteps
    private let onAddToCart: (Product) -> Void
    private let onShowAccounts: () -> Void
    // `var` because `showFilters()`, `showWishlist()` and `dismissSheet()` change it, and
    // `syncSheet(_:)` takes a swipe down.
    private(set) var presentedSheet: ProductSheet?
    // `var` because `playLaunchSteps()` plays them once, and the shop appears again on every tab
    // switch.
    private var hasPlayedLaunchSteps: Bool

    init(
        start: ProductsStart,
        membership: Membership,
        launchSteps: ShopLaunchSteps,
        onAddToCart: @escaping (Product) -> Void,
        onShowAccounts: @escaping () -> Void
    ) {
        self.start = start
        self.membership = membership
        self.launchSteps = launchSteps
        self.onAddToCart = onAddToCart
        self.onShowAccounts = onShowAccounts
        router = StackRouter(flow: start.flowID)
        presentedSheet = nil
        hasPlayedLaunchSteps = false
    }

    @ViewBuilder
    func makeRootFlow() -> some View {
        switch start {
        case .browse:
            makeShopFlow()
        case .search:
            makeSearchFlow()
        }
    }

    @ViewBuilder
    func makeProductFlow(for route: ProductRoute) -> some View {
        if let product = Product.find(id: route.id) {
            makeProductFlow(product)
        }
    }

    @ViewBuilder
    func makeSheetFlow(for sheet: ProductSheet) -> some View {
        switch sheet {
        case .filters:
            makeFiltersFlow()
        case .wishlist:
            makeWishlistFlow()
        }
    }

    func showProduct(_ product: Product) {
        router.push(ProductRoute(id: product.id))
    }

    func showFilters() {
        presentedSheet = .filters
    }

    func showWishlist() {
        presentedSheet = .wishlist
    }

    func addToCart(_ product: Product) {
        onAddToCart(product)
    }

    func showAccounts() {
        onShowAccounts()
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func syncSheet(_ sheet: ProductSheet?) {
        presentedSheet = sheet
    }

    // Pushes the launch products in one change, then makes the follow-up change while that push
    // still animates. Runs once, when the shop first appears.
    func playLaunchSteps() async {
        guard !hasPlayedLaunchSteps, !launchSteps.productIDs.isEmpty else {
            return
        }
        hasPlayedLaunchSteps = true
        let ids = launchSteps.productIDs
        router.push {
            for id in ids {
                ProductRoute(id: id)
            }
        }
        guard let followUp = launchSteps.followUp else {
            return
        }
        try? await Task.sleep(for: Self.followUpDelay)
        apply(followUp)
    }

    private func apply(_ followUp: ShopFollowUp) {
        switch followUp {
        case .pop:
            router.pop()
        case .popToRoot:
            router.popToRoot()
        case .link:
            openLinkedProduct()
        }
    }

    private func openLinkedProduct() {
        router.setPath {
            ProductRoute(id: Self.linkedProductID)
        }
    }

    private func makeShopFlow() -> some View {
        ProductListView(
            showsSignIn: membership == .guest,
            onSelect: { self.showProduct($0) },
            onFilter: { self.showFilters() },
            onSignIn: { self.showAccounts() }
        )
        .screenChrome(
            title: MainTab.shop.title,
            kind: nil,
            trail: ProductsTrail.shop
        )
    }

    private func makeSearchFlow() -> some View {
        SearchView(onSelect: { self.showProduct($0) })
            .screenChrome(
                title: MainTab.search.title,
                kind: nil,
                trail: ProductsTrail.search
            )
    }

    private func makeFiltersFlow() -> some View {
        FilterView(onApply: { self.dismissSheet() })
    }

    private func makeWishlistFlow() -> some View {
        WishlistView(
            products: Product.sampleWishlist,
            onDone: { self.dismissSheet() }
        )
    }

    private func makeProductFlow(_ product: Product) -> some View {
        ProductDetailView(
            product: product,
            canBuy: membership == .member,
            onAddToCart: { self.addToCart(product) },
            onSave: { self.showWishlist() }
        )
        .screenChrome(
            title: product.name,
            kind: nil,
            trail: ProductsTrail.product(product, from: start)
        )
    }
}

// The route trail for each products screen.
extension ProductsStart {
    // Names the stack in Waypoint's logs and debug tree.
    var flowID: FlowID {
        switch self {
        case .browse:
            return FlowID("shop")
        case .search:
            return FlowID("search")
        }
    }
}

enum ProductsTrail {
    static let shop = [
        "shop",
    ]
    static let search = [
        "search",
    ]

    static func product(
        _ product: Product,
        from start: ProductsStart
    ) -> [String] {
        let root = start == .browse ? shop : search
        let step = product.name.lowercased()
        return root + [step]
    }
}
