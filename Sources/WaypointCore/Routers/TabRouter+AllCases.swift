//
//  TabRouter+AllCases.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension TabRouter where Tab: CaseIterable {
    /// Creates a root tab container with every case of `Tab`, in the order the cases are declared.
    ///
    /// Use ``init(tabs:selection:flow:stacks:popsToRootOnReselect:configuration:file:line:)``
    /// to show only some of the cases, or in another order.
    ///
    /// - Parameters:
    ///   - selection: The tab selected at the start.
    ///   - flow: The container's name in logs, events and saved state. Default: `tabs`.
    ///   - stacks: Where the tabs' pushed screens go. Default: ``TabStacks/perTab``.
    ///   - popsToRootOnReselect: Whether tapping the selected tab pops its stack to the root.
    ///     Default: `true`.
    ///   - configuration: The settings of the whole tree. Default:
    ///     ``NavigationConfiguration/default``.
    ///   - file: The file that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    ///   - line: The line that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    public convenience init(
        selection: Tab,
        flow: FlowID = FlowID("tabs"),
        stacks: TabStacks = .perTab,
        popsToRootOnReselect: Bool = true,
        configuration: NavigationConfiguration = .default,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let allTabs = Array(Tab.allCases)
        self.init(
            tabs: allTabs,
            selection: selection,
            flow: flow,
            stacks: stacks,
            popsToRootOnReselect: popsToRootOnReselect,
            configuration: configuration,
            file: file,
            line: line
        )
    }
}
