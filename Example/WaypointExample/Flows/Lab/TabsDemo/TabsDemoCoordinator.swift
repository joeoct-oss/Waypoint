//
//  TabsDemoCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint
import WaypointCore

// The Tabs story (TX-04): a tab container whose tabs change at run time. It starts with Shop and
// Search; Show all four tabs brings back Cart and Account, and Show two tabs takes them away again,
// each with one `TabRouter.setTabs(_:)` call. The selection stays when its tab stays, and falls
// back to the first tab, Shop, when its tab goes. Each tab hosts a Waypoint stack of its own.
//
// The tab bar is still SwiftUI's, bound to the tab router, until Waypoint draws tabs.
//
// Conformances:
// - `Observable` (from `@Observable`), so the demo redraws when the tabs or the selection change.
@MainActor
@Observable
final class TabsDemoCoordinator {
    private static let flowID = FlowID("labTabs")
    private static let fewTabs = [
        DemoTab.shop,
        DemoTab.search,
    ]

    let tabs: TabRouter<DemoTab>
    private let onClose: () -> Void

    // Whether every tab shows, so the button offers to take two away.
    var showsAllTabs: Bool {
        tabs.state.tabs.count == DemoTab.allCases.count
    }

    init(
        navigation: NavigationConfiguration,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        tabs = TabRouter(
            tabs: Self.fewTabs,
            selection: .shop,
            flow: Self.flowID,
            configuration: navigation
        )
    }

    func makeTabFlow(for tab: DemoTab) -> some View {
        WaypointStack(tabs.router(for: tab)) {
            TabsDemoView(
                tab: tab,
                selection: tabs.selection,
                showsAllTabs: showsAllTabs,
                onChangeTabs: { self.toggleTabs() },
                onClose: { self.close() }
            )
        }
    }

    func selectTab(_ tab: DemoTab) {
        tabs.select(tab)
    }

    func close() {
        onClose()
    }

    // Shows all four tabs, or only Shop and Search.
    func toggleTabs() {
        if showsAllTabs {
            tabs.setTabs(Self.fewTabs)
        } else {
            tabs.setTabs(DemoTab.allCases)
        }
    }
}

// A tab of the Tabs story.
//
// Conformances:
// - `String` raw value: gives each tab its name in logs, so its stack's flow is `shop`.
// - `NavigationTab`, so the demo's tab router selects it, and `TabView` can tag each tab with it.
// - `CaseIterable`, so Show all four tabs lists every tab from this one declaration.
enum DemoTab: String, NavigationTab, CaseIterable {
    case shop
    case search
    case cart
    case account

    var title: String {
        switch self {
        case .shop:
            return "Shop"
        case .search:
            return "Search"
        case .cart:
            return "Cart"
        case .account:
            return "Account"
        }
    }

    var symbolName: String {
        switch self {
        case .shop:
            return "bag"
        case .search:
            return "magnifyingglass"
        case .cart:
            return "cart"
        case .account:
            return "person.crop.circle"
        }
    }
}
