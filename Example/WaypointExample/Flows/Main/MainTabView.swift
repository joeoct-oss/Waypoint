//
//  MainTabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the main tabs the reader can see with the system tab bar, which is Liquid Glass from iOS 26. Each
// tab hosts its own stack.
struct MainTabView: View {
    let main: MainCoordinator

    var body: some View {
        TabView(selection: Binding(reading: main.tabs.selected, writing: main.tabs.select)) {
            ForEach(main.visibleTabs, id: \.self) { tab in
                tabContent(for: tab)
            }
        }
        .accessibilityIdentifier(Identifiers.mainTabs)
    }

    private func tabContent(for tab: MainTab) -> some View {
        main.makeTabFlow(for: tab)
            .tabItem { Label(tab.title, systemImage: tab.symbolName) }
            .badge(main.badge(for: tab))
            .tag(tab)
    }
}
