//
//  MainCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// The main tabs: Shop, Search, Cart and Account, each with its own coordinator, the same for guests
// and signed-in readers. `MainFactory` builds each tab's coordinator, and the main coordinator
// keeps them. Cart's tab shows how many products the cart holds. Its account gate presents the
// accounts sheet over the tabs when an action needs an account.
//
// The tabs run on one Waypoint `TabRouter` with one stack around them all (`stacks: .shared`), as
// in UIKit with `hidesBottomBarWhenPushed`: a pushed screen covers the tab bar, and the bar slides
// away with the tab's root. Waypoint makes the tab router with `makeRouter()` the first time it is
// read, which `init` does, and asks `tabCoordinator(for:)` for each tab's coordinator then, the
// selected tab's first: its router becomes the shared stack, and every other tab's router sends
// its calls there, so no coordinator holds a router another one owns. Selecting another tab pops
// the stack, so a tab opens at its root. The journey lines follow the reader across tabs:
// `tab_selected Cart ◀ Shop`, then the screen the cart shows, on the stack named after the selected
// tab's coordinator. The tab bar itself is still SwiftUI's `TabView`, bound to the router's
// selection, until Waypoint draws tabs itself.
//
// Conformances:
// - `TabCoordinator`, so Waypoint makes its router and makes each tab's router the shared stack.
final class MainCoordinator: TabCoordinator {
    private let factory: MainFactory
    private let onClearAllData: () -> Void
    // The navigation issues every tab shows in its banner.
    let issues: IssueLog

    // `lazy var` because the gate presents over the tab router, which Waypoint makes from
    // `makeRouter()` when `init` reads it. Never set again.
    private(set) lazy var gate = factory.makeGate(tabs: router)
    // `lazy var` for the same reason as `gate`: the rules set the tab router's fallbacks.
    private(set) lazy var rules = factory.makeRules(tabs: router)
    // `lazy var` because Waypoint asks for each tab's coordinator while it makes the tab router,
    // which the tab's coordinator then joins. Never set again.
    private(set) lazy var shop = factory.makeShop(
        gate: gate,
        cart: makeProductsCart()
    )
    // `lazy var` for the same reason as `shop`.
    private(set) lazy var search = factory.makeSearch(
        gate: gate,
        cart: makeProductsCart()
    )
    // `lazy var` for the same reason as `shop`.
    private(set) lazy var cart = factory.makeCart(
        gate: gate,
        onShopMore: { [weak self] in self?.router.select(.shop, trigger: "keep_shopping") }
    )
    // `lazy var` for the same reason as `shop`.
    private(set) lazy var account = factory.makeAccount(
        gate: gate,
        rules: rules,
        describeTree: { [weak self] in self?.router.debugTree() ?? "" },
        onClearAllData: onClearAllData
    )

    // The account gate's notice over the tabs. While checkout is up, its cover shows the notice
    // instead, so the reader sees one toast, not two.
    var tabsNotice: Notice? {
        cart.isCheckingOut ? nil : gate.notice
    }

    // The one stack every tab pushes onto.
    var sharedStack: StackRouter {
        router.router(for: router.selection)
    }

    // Whether a screen is pushed above the selected tab's root. Every tab pushes onto one stack,
    // which a tab switch pops, so its path belongs to the selected tab.
    var showsPushedScreen: Bool {
        !sharedStack.state.path.isEmpty
    }

    // The products coordinator of the selected tab: Search's while Search shows, else Shop's,
    // which Go to cart selects.
    private var selectedProducts: ProductsCoordinator {
        router.selection == .search ? search : shop
    }

    init(
        factory: MainFactory,
        issues: IssueLog,
        onClearAllData: @escaping () -> Void
    ) {
        self.factory = factory
        self.issues = issues
        self.onClearAllData = onClearAllData
        // Makes the tabs now, and with them every tab's coordinator, so each one joins the shared
        // stack before a screen reads it. Then a launch into the Lab opens it on that stack.
        _ = router
        account.openLaunchPath()
    }

    func makeRouter() -> TabRouter<MainTab> {
        factory.makeTabRouter()
    }

    func tabCoordinator(for tab: MainTab) -> any StackCoordinator {
        switch tab {
        case .shop:
            return shop
        case .search:
            return search
        case .cart:
            return cart
        case .account:
            return account
        }
    }

    // The tab the reader picked in the tab bar.
    func selectTab(_ tab: MainTab) {
        router.select(tab)
    }

    // What Shop and Search show of the cart, and where Add to cart and their cart buttons go.
    private func makeProductsCart() -> ProductsCart {
        ProductsCart(
            products: { [weak self] in self?.cart.products ?? [] },
            onAddToCart: { [weak self] in self?.addToCart($0) },
            onGoToCart: { [weak self] in self?.goToCart() },
            onCheckout: { [weak self] in self?.checkOut() }
        )
    }

    // Add to cart on Shop or Search: the product joins the cart, and Cart opens.
    private func addToCart(_ product: Product) {
        cart.add(product)
        router.select(.cart, trigger: "added_to_cart")
    }

    // TX-02: one transaction selects Shop and sets the stack's path to the cart's first product
    // with the cart above it. The tabs change once, the stack draws once, and Back goes to the
    // product.
    private func goToCart() {
        guard let first = cart.products.first else {
            return
        }
        router.transaction {
            $0.select(MainTab.shop)
            $0.router(for: MainTab.shop).setPath {
                ProductRoute(id: first.id, preview: first)
                ShopCartRoute()
            }
        }
    }

    // Check out from the cart pushed on Shop: the Cart tab runs checkout, as its own Check out
    // does.
    private func checkOut() {
        router.select(.cart, trigger: "checkout_button")
        cart.checkOut()
    }

    func badge(for tab: MainTab) -> Int {
        tab == .cart ? cart.products.count : 0
    }

    // Each tab's root, drawn by its coordinator.
    @ViewBuilder
    func makeTabFlow(for tab: MainTab) -> some View {
        switch tab {
        case .shop:
            shop.root
        case .search:
            search.root
        case .cart:
            cart.root
        case .account:
            account.root
        }
    }

    // Shop and Search push the same routes onto the one stack, so the selected tab's coordinator
    // draws them.
    func makeProductFlow(for route: ProductRoute) -> some View {
        selectedProducts.makeProductFlow(for: route)
    }

    func makeCollectionFlow(for route: CollectionRoute) -> some View {
        selectedProducts.makeCollectionFlow(for: route)
    }

    func makeShopCartFlow() -> some View {
        selectedProducts.makeCartFlow()
    }

    func makeAccountFlow(for route: AccountRoute) -> some View {
        account.makeDestination(for: route)
    }

    func makeAuthFlow(_ auth: AuthCoordinator) -> some View {
        factory.makeAuthFlow(auth)
    }
}
