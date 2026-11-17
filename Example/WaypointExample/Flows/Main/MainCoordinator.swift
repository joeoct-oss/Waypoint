//
//  MainCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The main tabs: Shop, Search, Cart and Account, each with its own coordinator and stack. Guests see only
// Shop and Search, with Sign in in the shop's bar. The main coordinator makes the tabs once and keeps them,
// so each tab keeps its place while the reader switches tabs.
@MainActor
final class MainCoordinator {
    private static let guestTabs: [MainTab] = [
        .shop,
        .search,
    ]

    let visibleTabs: [MainTab]
    let tabs: TabSelection
    let shop: ProductsCoordinator
    let search: ProductsCoordinator
    let cart: CartCoordinator
    let account: AccountCoordinator

    init(
        membership: Membership,
        launch: LaunchOptions,
        onShowAccounts: @escaping () -> Void
    ) {
        let tabs = TabSelection(selected: launch.opensLab ? .account : .shop)
        visibleTabs = membership == .guest ? Self.guestTabs : MainTab.allCases
        self.tabs = tabs
        shop = ProductsCoordinator(
            start: .browse,
            membership: membership,
            onShowCart: { tabs.select(.cart) },
            onShowAccounts: onShowAccounts
        )
        search = ProductsCoordinator(
            start: .search,
            membership: membership,
            onShowCart: { tabs.select(.cart) },
            onShowAccounts: onShowAccounts
        )
        cart = CartCoordinator(onShopMore: { tabs.select(.shop) })
        account = AccountCoordinator(
            launch: launch,
            onSignOut: onShowAccounts
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
