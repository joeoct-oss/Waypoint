//
//  TabsDemoView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// Draws the Tabs story's tab container with the system tab bar, one tab for each tab the router
// has now.
struct TabsDemoFlowView: View {
    let demo: TabsDemoCoordinator

    var body: some View {
        TabView(selection: Binding(reading: demo.router.selection, writing: demo.selectTab)) {
            ForEach(demo.router.state.tabs, id: \.self) { tab in
                demo.makeTabFlow(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbolName) }
                    .tag(tab)
            }
        }
        .accessibilityIdentifier(Identifiers.tabsDemo)
    }
}

// One tab of the Tabs story: which tab is selected, the button that changes the tabs, and Close.
// The view only reports the taps.
struct TabsDemoView: View {
    let tab: DemoTab
    let selection: DemoTab
    let showsAllTabs: Bool
    let onChangeTabs: () -> Void
    let onClose: () -> Void

    private var buttonTitle: String {
        showsAllTabs ? "Show two tabs" : "Show all four tabs"
    }

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: onClose)
                .accessibilityIdentifier(Identifiers.labDemoClose)
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Selected", value: selection.title)
                    .accessibilityIdentifier(Identifiers.tabsDemoSelection)
            } footer: {
                Text("Removing the selected tab falls back to Shop. Keeping it keeps the selection.")
            }
            Section {
                Button(buttonTitle, action: onChangeTabs)
                    .accessibilityIdentifier(Identifiers.tabsDemoChange)
            }
        }
        .exampleList()
        .navigationTitle(tab.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeItem }
    }
}
