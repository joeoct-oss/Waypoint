//
//  MainTabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the main tabs with the system tab bar, which is Liquid Glass from iOS 26, and the accounts
// sheet the account gate presents over them. Each tab hosts its own stack. The gate runs the action
// it held once the sheet has closed.
struct MainTabView: View {
    let main: MainCoordinator

    var body: some View {
        TabView(selection: Binding(reading: main.tabs.selected, writing: main.tabs.select)) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
            }
        }
        .accessibilityIdentifier(Identifiers.mainTabs)
        .sheet(
            item: Binding(reading: main.gate.presentedAuth, writing: main.gate.syncAuth),
            onDismiss: main.gate.runHeldAction
        ) {
            main.makeAuthFlow($0)
        }
    }

    private func tabContent(for tab: MainTab) -> some View {
        main.makeTabFlow(for: tab)
            .tabItem { Label(tab.title, systemImage: tab.symbolName) }
            .badge(main.badge(for: tab))
            .tag(tab)
    }
}
