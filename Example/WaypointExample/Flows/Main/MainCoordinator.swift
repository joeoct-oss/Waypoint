//
//  MainCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The main tabs: Shop, Search, Cart and Account, each with its own coordinator and stack, the same
// for guests and signed-in readers. The main coordinator makes the tabs once and keeps them, so
// each tab keeps its place while the reader switches tabs. Cart's tab shows how many products the
// cart holds. Its account gate presents the accounts sheet over the tabs when an action needs an
// account.
@MainActor
final class MainCoordinator {
    let gate: AccountGate
    let tabs: TabSelection
    let shop: ProductsCoordinator
    let search: ProductsCoordinator
    let cart: CartCoordinator
    let account: AccountCoordinator

    init(
        services: AppServices,
        launch: LaunchOptions,
        onClearAllData: @escaping () -> Void
    ) {
        let gate = AccountGate(
            session: services.session,
            service: services.auth
        )
        let tabs = TabSelection(selected: launch.opensLab ? .account : .shop)
        let cart = CartCoordinator(
            store: services.store,
            addressBook: services.addresses,
            gate: gate,
            navigation: services.navigation,
            onShopMore: { tabs.select(.shop) }
        )
        let addToCart = { (product: Product) in
            cart.add(product)
            tabs.select(.cart)
        }
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
            store: services.store,
            gate: gate,
            launchSteps: launch.shopSteps,
            navigation: navigation,
            onAddToCart: addToCart
        )
        search = ProductsCoordinator(
            start: .search,
            store: services.store,
            gate: gate,
            launchSteps: .none,
            navigation: navigation,
            onAddToCart: addToCart
        )
        account = AccountCoordinator(
            launch: launch,
            session: services.session,
            addressBook: services.addresses,
            gate: gate,
            navigation: services.navigation,
            onClearAllData: onClearAllData
        )
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
