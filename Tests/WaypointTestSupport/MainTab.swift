//
//  MainTab.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A shared test tab type for a three-tab app.
///
/// Conformances:
/// - `String` raw value: gives each case a readable name in logs and saved state.
/// - `Hashable`, required by tab state, which selects and compares tabs.
/// - `Codable`, required by tab state, which saves and restores the selection.
/// - `Sendable`, required by tab state, so changes that name the tab can leave the main actor.
package enum MainTab: String, Hashable, Codable, Sendable {
    /// The home tab.
    case home
    /// The shop tab.
    case shop
    /// The profile tab.
    case profile
}
