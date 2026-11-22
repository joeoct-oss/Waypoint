//
//  TabStacks.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Where a tab container's pushed screens go.
///
/// Conformances:
/// - `Sendable`, so the setting can be read off the main actor.
/// - `Hashable`, so apps and tests can compare it.
public enum TabStacks: Sendable, Hashable {
    /// Each tab has its own stack and keeps it when the reader switches tabs. The default.
    case perTab

    /// The tabs share one stack above the tab bar. A pushed screen covers the bar, as a
    /// `NavigationStack` around a `TabView` does, so the system slides the bar away with the tab's
    /// root. Selecting another tab, or removing the selected one, pops the pushed screens. A sheet
    /// or cover the stack presents stays, since it covers the tab bar too.
    case shared
}
