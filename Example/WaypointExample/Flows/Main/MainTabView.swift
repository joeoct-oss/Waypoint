//
//  MainTabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import WaypointCore

// Draws the main tabs with the system tab bar, which is Liquid Glass from iOS 26, and the accounts
// sheet the account gate presents over them. Each tab hosts its own stack. The gate runs the action
// it held once the sheet has closed, and its notices show over the tabs.
struct MainTabView: View {
    let main: MainCoordinator

    var body: some View {
        TabView(selection: Binding(reading: main.tabs.selection, writing: main.selectTab)) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
            }
        }
        .accessibilityIdentifier(Identifiers.mainTabs)
        .noticeOverlay(main.tabsNotice)
        .sheet(
            isPresented: Binding(reading: main.gate.isShowingAuth, writing: main.gate.syncAuth),
            onDismiss: main.gate.finishAuth
        ) {
            if let auth = main.gate.presentedAuth {
                main.makeAuthFlow(auth)
                    .sheetOptions(main.gate.authSheetOptions)
            }
        }
    }

    private func tabContent(for tab: MainTab) -> some View {
        main.makeTabFlow(for: tab)
            .tabItem { Label(tab.title, systemImage: tab.symbolName) }
            .badge(main.badge(for: tab))
            .tag(tab)
    }
}
