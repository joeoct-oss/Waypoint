//
//  TabsDemoCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// The Tabs story (TX-04): a tab container whose tabs change at run time. It starts with Shop and
// Search; Show all four tabs brings back Cart and Account, and Show two tabs takes them away again,
// each with one `TabRouter.setTabs(_:)` call. The selection stays when its tab stays, and falls
// back to the first tab, Shop, when its tab goes.
//
// It stores no router: `TabCoordinator` makes one with `makeRouter()` the first time it is read,
// and asks `tabCoordinator(for:)` for each tab's coordinator then, so each tab's stack is that
// coordinator's router. A tab added later gets its coordinator when it is added. A removed tab's
// coordinator is kept for the life of the demo, and gets the tab's new stack when the tab is added
// back.
//
// The tab bar is still SwiftUI's, bound to the tab router, until Waypoint draws tabs.
//
// Conformances:
// - `TabCoordinator`, so Waypoint makes its router and hands each tab's coordinator its stack.
// - `Observable` (from `@Observable`), so the demo redraws when the tabs or the selection change.
@Observable
final class TabsDemoCoordinator: TabCoordinator {
    private static let flowID = FlowID("labTabs")
    private static let fewTabs = [
        DemoTab.shop,
        DemoTab.search,
    ]

    private let navigation: NavigationConfiguration
    private let onClose: () -> Void
    // `var` because each tab's coordinator is made the first time Waypoint asks for it or its tab
    // is drawn, and kept, so a tab added back gets the same coordinator. Only `child(for:)` changes
    // it. Not observed, because it changes while a tab is drawn.
    @ObservationIgnored private var tabCoordinators: [DemoTab: TabsDemoTabCoordinator]

    // Whether every tab shows, so the button offers to take two away.
    var showsAllTabs: Bool {
        router.state.tabs.count == DemoTab.allCases.count
    }

    init(
        navigation: NavigationConfiguration,
        onClose: @escaping () -> Void
    ) {
        self.navigation = navigation
        self.onClose = onClose
        tabCoordinators = [:]
    }

    func makeRouter() -> TabRouter<DemoTab> {
        TabRouter(
            tabs: Self.fewTabs,
            selection: .shop,
            flow: Self.flowID,
            configuration: navigation
        )
    }

    func tabCoordinator(for tab: DemoTab) -> any StackCoordinator {
        child(for: tab)
    }

    func makeTabFlow(for tab: DemoTab) -> some View {
        child(for: tab).view
    }

    func selectTab(_ tab: DemoTab) {
        router.select(tab)
    }

    func close() {
        onClose()
    }

    // Shows all four tabs, or only Shop and Search.
    func toggleTabs() {
        if showsAllTabs {
            router.setTabs(Self.fewTabs)
        } else {
            router.setTabs(DemoTab.allCases)
        }
    }

    // The tab's coordinator, made the first time it is needed and kept.
    private func child(for tab: DemoTab) -> TabsDemoTabCoordinator {
        if let kept = tabCoordinators[tab] {
            return kept
        }
        let child = TabsDemoTabCoordinator(tab: tab, demo: self)
        tabCoordinators[tab] = child
        return child
    }
}

// The coordinator of one tab of the Tabs story. Its router is the tab's stack, named after the tab
// because it keeps the default root name, and it draws that stack with its own `view`: the tab's
// one screen, which shows the selection and the tab container's buttons. The tab bar is still
// SwiftUI's until Waypoint draws tabs.
//
// Conformances:
// - `StackCoordinator`, so Waypoint makes its router, the tab coordinator makes it the tab's stack,
//   and Waypoint draws its screen.
final class TabsDemoTabCoordinator: StackCoordinator {
    private let tab: DemoTab
    // The tab container, which keeps this coordinator, so it is held without keeping it alive.
    // `var` because a weak reference must be one: it reads `nil` once the Lab lets the demo go.
    private weak var demo: TabsDemoCoordinator?

    var root: some View {
        if let demo {
            TabsDemoView(
                tab: tab,
                selection: demo.router.selection,
                showsAllTabs: demo.showsAllTabs,
                onChangeTabs: { demo.toggleTabs() },
                onClose: { demo.close() }
            )
        }
    }

    init(tab: DemoTab, demo: TabsDemoCoordinator) {
        self.tab = tab
        self.demo = demo
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
