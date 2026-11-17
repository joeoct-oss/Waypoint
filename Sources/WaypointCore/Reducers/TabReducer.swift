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
/// - `Tab: Hashable & Codable & Sendable`, the same tab types as `TabState`.
/// - `Sendable`, so commands can be queued and logged.
/// - `Equatable`, so tests can compare commands.
enum TabCommand<Tab: Hashable & Codable & Sendable>: Sendable, Equatable {
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
        var next = state
        next.selection = tab
        return .changed(next, [selectionChange(from: state.selection, to: tab)])
    }

    /// Replaces the tabs. If the selected tab is removed, the first tab is selected.
    private static func setTabs<Tab>(_ tabs: [Tab], on state: TabState<Tab>) -> Reduction<TabState<Tab>> {
        guard let first = tabs.first else {
            return .rejected(.noTabs)
        }
        guard tabs != state.tabs else {
            return .unchanged
        }
        var next = state
        next.tabs = tabs
        guard !tabs.contains(state.selection) else {
            return .changed(next, [])
        }
        next.selection = first
        return .changed(next, [selectionChange(from: state.selection, to: first)])
    }

    /// `tabSelected` with both tabs named.
    private static func selectionChange<Tab: Hashable>(from old: Tab, to new: Tab) -> NavigationChange {
        .tabSelected(from: DescriptionFormat.name(of: old), to: DescriptionFormat.name(of: new))
    }
}
