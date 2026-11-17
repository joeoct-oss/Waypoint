//
//  MainCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The main tabs: Shop, Search, Cart and Account, each with its own coordinator and stack. The main
// coordinator makes them once and keeps them, so each tab keeps its place while the reader switches tabs.
@MainActor
final class MainCoordinator {
    let tabs: TabSelection
    let shop: ProductsCoordinator
    let search: ProductsCoordinator
    let cart: CartCoordinator
    let account: AccountCoordinator

    init(
        launch: LaunchOptions,
        onSignOut: @escaping () -> Void
    ) {
        let tabs = TabSelection(selected: launch.opensLab ? .account : .shop)
        self.tabs = tabs
        shop = ProductsCoordinator(
            start: .browse,
            onShowCart: { tabs.select(.cart) }
        )
        search = ProductsCoordinator(
            start: .search,
            onShowCart: { tabs.select(.cart) }
        )
        cart = CartCoordinator(onShopMore: { tabs.select(.shop) })
        account = AccountCoordinator(
            launch: launch,
            onSignOut: onSignOut
        )
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
