//
//  MainCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import WaypointCore

// The main tabs: Shop, Search, Cart and Account, each with its own coordinator and stack, the same
// for guests and signed-in readers. The main coordinator makes the tabs once and keeps them, so
// each tab keeps its place while the reader switches tabs. Cart's tab shows how many products the
// cart holds. Its account gate presents the accounts sheet over the tabs when an action needs an
// account.
//
// The tabs run on one Waypoint `TabRouter`, and each tab's coordinator draws its tab's stack
// router, so the whole tab bar is one tree. The journey lines then follow the reader across tabs:
// `tab_selected Cart ◀ Shop`, then the screen the cart shows. The tab bar itself is still SwiftUI's
// `TabView`, bound to the router's selection, until Waypoint draws tabs itself.
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
        // The journey box names each router by the coordinator that owns it; each tab's
        // coordinator names its own.
        tabs.setCoordinator(self)
    }

    // The tab the reader picked in the tab bar.
    func selectTab(_ tab: MainTab) {
        tabs.select(tab)
    }

    // TX-02: one transaction selects Shop and sets its path to the cart's first product with the
    // cart above it. The tabs change once, the stack draws once, and Back goes to the product.
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
