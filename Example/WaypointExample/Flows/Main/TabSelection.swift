//
//  TabSelection.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

// The selected main tab, shared by the main coordinator and the tabs' own coordinators, so a flow
// in one tab can send the reader to another, such as Add to cart opening Cart.
//
// Conformances:
// - `Observable` (from `@Observable`), so the tab bar redraws when a flow selects another tab.
@MainActor
@Observable
final class TabSelection {
    // `var` because `select(_:)` changes it, from a flow or from the tab bar itself.
    private(set) var selected: MainTab

    init(selected: MainTab) {
        self.selected = selected
    }

    func select(_ tab: MainTab) {
        selected = tab
    }
}
