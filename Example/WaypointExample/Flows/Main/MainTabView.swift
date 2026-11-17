//
//  MainTabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the main tabs with the system tab bar, which is Liquid Glass from iOS 26. Each tab hosts its own
// stack.
struct MainTabView: View {
    let main: MainCoordinator

    var body: some View {
        TabView(selection: Binding(reading: main.tabs.selected, writing: main.tabs.select)) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
            }
        }
        .accessibilityIdentifier(Identifiers.mainTabs)
    }

    private func tabContent(for tab: MainTab) -> some View {
        main.makeTabFlow(for: tab)
            .tabItem { Label(tab.title, systemImage: tab.symbolName) }
            .tag(tab)
    }
}
