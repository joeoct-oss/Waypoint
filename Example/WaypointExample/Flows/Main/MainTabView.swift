//
//  MainTabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws the main tabs with the system tab bar, which is Liquid Glass from iOS 26, inside the one
// stack every tab pushes onto, and the accounts sheet the account gate presents over them. A pushed
// screen covers the tab bar, and the bar slides away with the tab's root, with no code of ours.
// Each route type has one destination, since a stack takes one per type. Every tab's sheets and
// covers sit on the stack too, since one on a tab's root doesn't show under a pushed screen. The
// newest navigation issue from Shop or Search shows over their pushed screens, and above the tab
// bar on their roots. The gate runs the action it held once the sheet has closed, and its notices
// show over the tabs.
struct MainTabView: View {
    let main: MainCoordinator

    var body: some View {
        WaypointStack(main.tabs.router(for: .shop)) {
            TabView(selection: Binding(reading: main.tabs.selection, writing: main.selectTab)) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    tabContent(for: tab)
                }
            }
            .accessibilityIdentifier(Identifiers.mainTabs)
            .modifier(MainTabChrome(main: main))
            .destination(ProductRoute.self) { main.makeProductFlow(for: $0) }
            .destination(CollectionRoute.self) { main.makeCollectionFlow(for: $0) }
            .destination(ShopCartRoute.self) { _ in main.makeShopCartFlow() }
            .destination(AccountRoute.self) { main.makeAccountFlow(for: $0) }
        }
        .modifier(ProductsSheet(products: main.shop))
        .modifier(ProductsSheet(products: main.search))
        .modifier(CheckoutCover(cart: main.cart))
        .modifier(LabDemoCover(account: main.account))
        .overlay(alignment: .bottom) { pushedIssue }
        .noticeOverlay(main.tabsNotice)
        .sheet(
            isPresented: Binding(reading: main.gate.isShowingAuth, writing: main.gate.syncAuth),
            onDismiss: main.gate.finishAuth
        ) {
            if let auth = main.gate.tabsAuth {
                main.makeAuthFlow(auth)
                    .sheetOptions(main.gate.authSheetOptions)
            }
        }
    }

    // Shop's and Search's newest navigation issue, while a screen is pushed from either. A tab's
    // root shows its own, above the tab bar, which this one would cover.
    @ViewBuilder
    private var pushedIssue: some View {
        if main.showsPushedProducts {
            IssueBanner(issues: main.shop.issues)
        }
    }

    private func tabContent(for tab: MainTab) -> some View {
        main.makeTabFlow(for: tab)
            .tabItem { Label(tab.title, systemImage: tab.symbolName) }
            .badge(main.badge(for: tab))
            .tag(tab)
    }
}

// The selected tab root's title and Shop's toolbar. A tab root's own `navigationTitle` and
// `toolbar` don't reach the bar from inside `TabView`, so the main tabs set them for the tab that
// shows, on the one stack's bar.
//
// Conformances:
// - `ViewModifier`, so `MainTabView` gives it to the `TabView`.
private struct MainTabChrome: ViewModifier {
    let main: MainCoordinator

    private var selected: MainTab {
        main.tabs.selection
    }

    func body(content: Content) -> some View {
        content
            .navigationTitle(selected.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if selected == .shop {
                    main.shop.makeShopToolbar()
                }
            }
    }
}
