//
//  MainCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import WaypointCore

// The main tabs: Shop, Search, Cart and Account, each with its own coordinator, the same for guests
// and signed-in readers. The main coordinator makes the tabs once and keeps them. Cart's tab shows
// how many products the cart holds. Its account gate presents the accounts sheet over the tabs when
// an action needs an account.
//
// The tabs run on one Waypoint `TabRouter` with one stack around them all (`stacks: .shared`), as
// in UIKit with `hidesBottomBarWhenPushed`: a pushed screen covers the tab bar, and the bar slides
// away with the tab's root. Every tab's coordinator pushes onto that one stack, and selecting
// another tab pops it, so a tab opens at its root. The journey lines follow the reader across
// tabs: `tab_selected Cart ◀ Shop`, then the screen the cart shows. The tab bar itself is still
// SwiftUI's `TabView`, bound to the router's selection, until Waypoint draws tabs itself.
@MainActor
final class MainCoordinator {
    let gate: AccountGate
    let tabs: TabRouter<MainTab>
    let shop: ProductsCoordinator
    let search: ProductsCoordinator
    let cart: CartCoordinator
    let account: AccountCoordinator

    // The account gate's notice over the tabs. While checkout is up, its cover shows the notice
    // instead, so the reader sees one toast, not two.
    var tabsNotice: Notice? {
        cart.isCheckingOut ? nil : gate.notice
    }

    init(
        services: AppServices,
        launch: LaunchOptions,
        onClearAllData: @escaping () -> Void
    ) {
        // The tab bar pops nothing on a second tap, as before every tab ran on Waypoint.
        let tabs = TabRouter(
            selection: launch.opensLab ? MainTab.account : .shop,
            stacks: .shared,
            popsToRootOnReselect: false,
            configuration: services.navigation
        )
        tabs.setPresentationDefaults(AppSheets.defaults)
        let gate = AccountGate(
            session: services.session,
            service: services.auth,
            tabs: tabs
        )
        let cart = CartCoordinator(
            router: tabs.router(for: .cart),
            store: services.store,
            addressBook: services.addresses,
            gate: gate,
            onShopMore: { tabs.select(.shop, trigger: "keep_shopping") }
        )
        let addToCart = { (product: Product) in
            cart.add(product)
            tabs.select(.cart, trigger: "added_to_cart")
        }
        let productsCart = ProductsCart(
            products: { cart.products },
            onGoToCart: { Self.goToCart(tabs: tabs, cart: cart) },
            onCheckout: { Self.checkOut(tabs: tabs, cart: cart) }
        )
        let navigation = ProductsNavigation(
            configuration: services.navigation,
            issues: services.issues,
            usesSystemLinks: launch.usesSystemLinks,
            linksToMissingDestination: launch.linksToMissingDestination
        )
        self.gate = gate
        self.tabs = tabs
        self.cart = cart
        shop = ProductsCoordinator(
            start: .browse,
            router: tabs.router(for: .shop),
            store: services.store,
            gate: gate,
            launchSteps: launch.shopSteps,
            navigation: navigation,
            onAddToCart: addToCart,
            cart: productsCart
        )
        search = ProductsCoordinator(
            start: .search,
            router: tabs.router(for: .search),
            store: services.store,
            gate: gate,
            launchSteps: .none,
            navigation: navigation,
            onAddToCart: addToCart,
            cart: productsCart
        )
        account = AccountCoordinator(
            router: tabs.router(for: .account),
            launch: launch,
            session: services.session,
            store: services.store,
            addressBook: services.addresses,
            gate: gate,
            navigation: services.navigation,
            events: services.events,
            describeTree: { [tabs] in tabs.debugTree() },
            onClearAllData: onClearAllData
        )
        // The journey box names each router by the coordinator that owns it. The tabs share one
        // stack, which every tab coordinator names in turn, so the main coordinator, which owns
        // it, names it last. The journey names the selected tab beside it.
        tabs.setCoordinator(self)
        tabs.router(for: .shop).setCoordinator(self)
    }

    // The tab the reader picked in the tab bar.
    func selectTab(_ tab: MainTab) {
        tabs.select(tab)
    }

    // TX-02: one transaction selects Shop and sets the stack's path to the cart's first product
    // with the cart above it. The tabs change once, the stack draws once, and Back goes to the
    // product.
    private static func goToCart(
        tabs: TabRouter<MainTab>,
        cart: CartCoordinator
    ) {
        guard let first = cart.products.first else {
            return
        }
        tabs.transaction {
            $0.select(MainTab.shop)
            $0.router(for: MainTab.shop).setPath {
                ProductRoute(id: first.id, preview: first)
                ShopCartRoute()
            }
        }
    }

    // Check out from the cart pushed on Shop: the Cart tab runs checkout, as its own Check out
    // does.
    private static func checkOut(
        tabs: TabRouter<MainTab>,
        cart: CartCoordinator
    ) {
        tabs.select(.cart, trigger: "checkout_button")
        cart.checkOut()
    }

    func badge(for tab: MainTab) -> Int {
        tab == .cart ? cart.products.count : 0
    }

    @ViewBuilder
    func makeTabFlow(for tab: MainTab) -> some View {
        switch tab {
        case .shop:
            makeShopFlow()
        case .search:
            makeSearchFlow()
        case .cart:
            makeCartFlow()
        case .account:
            makeAccountFlow()
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

    // Whether Shop or Search is selected with a screen pushed above its root.
    var showsPushedProducts: Bool {
        let isProductsTab = tabs.selection == .shop || tabs.selection == .search
        return isProductsTab && !shop.router.state.path.isEmpty
    }

    // The products coordinator of the selected tab: Search's while Search shows, else Shop's,
    // which Go to cart selects.
    private var selectedProducts: ProductsCoordinator {
        tabs.selection == .search ? search : shop
    }

    func makeAuthFlow(_ auth: AuthCoordinator) -> some View {
        AuthFlowView(auth: auth)
    }

    private func makeShopFlow() -> some View {
        ProductsFlowView(products: shop)
    }

    private func makeSearchFlow() -> some View {
        ProductsFlowView(products: search)
    }

    private func makeCartFlow() -> some View {
        CartFlowView(cart: cart)
    }

    private func makeAccountFlow() -> some View {
        AccountFlowView(account: account)
    }
}
