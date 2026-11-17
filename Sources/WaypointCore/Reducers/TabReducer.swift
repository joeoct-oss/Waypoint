//
//  TabReducer.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A change to a tab container.
///
/// Conformances:
/// - `Tab: NavigationTab`, the same tab types as `TabState`.
/// - `Sendable`, so commands can be queued and logged.
/// - `Equatable`, so tests can compare commands.
enum TabCommand<Tab: NavigationTab>: Sendable, Equatable {
    /// Select a tab.
    case select(Tab)
    /// Replace the list of tabs.
    case setTabs([Tab])
}

/// Applies tab commands. Pure: no routers, no globals.
enum TabReducer {
    /// Applies one command. The selection is always one of the tabs.
    static func reduce<Tab>(_ state: TabState<Tab>, _ command: TabCommand<Tab>) -> Reduction<TabState<Tab>> {
        switch command {
        case .select(let tab):
            return select(tab, in: state)
        case .setTabs(let tabs):
            return setTabs(tabs, on: state)
        }
    }

    /// Selects a tab that is one of the tabs.
    private static func select<Tab>(_ tab: Tab, in state: TabState<Tab>) -> Reduction<TabState<Tab>> {
        guard state.tabs.contains(tab) else {
            return .rejected(.unknownTab(DescriptionFormat.name(of: tab)))
        }
        guard tab != state.selection else {
            return .unchanged
        }
        let changes = [selectionChange(from: state.selection, to: tab)]
        return .changed(state.withSelection(tab), changes)
    }

    /// Replaces the tabs. If the selected tab is removed, the first tab is selected.
    private static func setTabs<Tab>(_ tabs: [Tab], on state: TabState<Tab>) -> Reduction<TabState<Tab>> {
        guard let first = tabs.first else {
            return .rejected(.noTabs)
        }
        guard tabs != state.tabs else {
            return .unchanged
        }
        let next = state.withTabs(tabs)
        guard !tabs.contains(state.selection) else {
            let noChanges: [NavigationChange] = []
            return .changed(next, noChanges)
        }
        let changes = [selectionChange(from: state.selection, to: first)]
        return .changed(next, changes)
    }

    /// `tabSelected` with both tabs named.
    private static func selectionChange<Tab: NavigationTab>(from old: Tab, to new: Tab) -> NavigationChange {
        .tabSelected(from: DescriptionFormat.name(of: old), to: DescriptionFormat.name(of: new))
    }
}
