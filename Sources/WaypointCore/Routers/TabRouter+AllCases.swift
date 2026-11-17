//
//  TabRouter+AllCases.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension TabRouter where Tab: CaseIterable {
    /// Creates a root tab container with every case of `Tab`, in the order the cases are declared.
    ///
    /// Use ``init(tabs:selection:flow:popsToRootOnReselect:)`` to show only some of the cases, or
    /// in another order.
    ///
    /// - Parameters:
    ///   - selection: The tab selected at the start.
    ///   - flow: The container's name in logs, events and saved state. Default: `tabs`.
    ///   - popsToRootOnReselect: Whether tapping the selected tab pops its stack to the root.
    ///     Default: `true`.
    public convenience init(
        selection: Tab,
        flow: FlowID = FlowID("tabs"),
        popsToRootOnReselect: Bool = true
    ) {
        let allTabs = Array(Tab.allCases)
        self.init(
            tabs: allTabs,
            selection: selection,
            flow: flow,
            popsToRootOnReselect: popsToRootOnReselect
        )
    }
}
