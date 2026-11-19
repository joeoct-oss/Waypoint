//
//  TabRouter+Tree.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Conformances:
/// - `TreeNode`, so the tree can walk, detach and inherit through it.
extension TabRouter: TreeNode {
    /// The committed presented flow.
    var presentedNode: (any TreeNode)? {
        presented
    }

    /// Each tab's router in tab order, then the presented flow.
    var childNodes: [any TreeNode] {
        let tabs: [any TreeNode] = state.tabs.compactMap { tabRouters[$0] }
        return tabs + (presented.map { [$0] } ?? [])
    }

    /// A container has no path of its own.
    var currentPath: [AnyRoute] {
        []
    }

    /// The selected tab's stack.
    var shownStack: any TreeNode {
        visibleStack ?? self
    }

    /// The selected tab's routes.
    var shownRoutes: [AnyRoute] {
        visibleStack?.shownRoutes ?? []
    }

    /// Whether the selected tab's stack was made with a root route.
    var showsRootRoute: Bool {
        visibleStack?.showsRootRoute ?? false
    }

    /// `tabs      home · [shop] · profile`, with each tab's stack and the presented flow below.
    func readableTree(_ naming: RouteNaming) -> ReadableTree {
        let snapshot = current
        let names = snapshot.state.tabs.map { tab in
            Self.tabLabel(tab, selected: tab == snapshot.state.selection)
        }
        let detail = names.joined(separator: naming.usesSymbols ? " · " : " | ")
        let tabTrees = snapshot.state.tabs.compactMap { tab in
            snapshot.tabRouters[tab]?.readableTree(naming)
        }
        let presentedTree = snapshot.presented.map { child in
            [child.readableTree(naming).presented(as: snapshot.state.presentation?.style)]
        }
        return ReadableTree(name: flowID.name, detail: detail, children: tabTrees + (presentedTree ?? []))
    }

    /// A tab's name, in brackets when it is selected.
    private static func tabLabel(_ tab: Tab, selected: Bool) -> String {
        let name = DescriptionFormat.name(of: tab)
        return selected ? "[\(name)]" : name
    }
}

/// Conformances:
/// - `PresentingRouter`, so it can present a flow above all its tabs.
extension TabRouter: PresentingRouter {
    /// The working copy's presentation.
    var workingPresentation: Presentation? {
        current.state.presentation
    }

    /// The presented router as it is in the current transaction, or the committed one.
    var currentPresented: StackRouter? {
        current.presented
    }

    /// The selected tab's stack, as it is in the current transaction.
    var visibleStack: StackRouter? {
        currentRouter(for: current.state.selection)
    }

    /// Each tab's router, which is inside this flow.
    var workingInFlowChildren: [any PresentingRouter] {
        let snapshot = current
        return snapshot.state.tabs.compactMap { snapshot.tabRouters[$0] }
    }

    /// Presents a flow in the working copy, or clears it with `nil`.
    func updateWorkingPresentation(_ presentation: Presentation?, presented router: StackRouter?) {
        updateWorkingCopy { snapshot in
            snapshot.presenting(presentation, by: router)
        }
    }
}

extension TabRouter {
    /// One tab's router as it is in the current transaction, or the committed one.
    func currentRouter(for tab: Tab) -> StackRouter? {
        current.tabRouters[tab]
    }

    /// Selects a tab, or pops the selected tab's stack when it is selected again.
    func selectStep(_ tab: Tab, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        let snapshot = current
        guard tab == snapshot.state.selection, popsToRootOnReselect, let stack = snapshot.tabRouters[tab] else {
            return tabStep(.select(tab), in: store)
        }
        return stack.stackStep(.popToRoot, in: store)
    }

    /// Replaces the tabs, creating routers for new tabs and dropping removed ones.
    func setTabsStep(_ tabs: [Tab], in store: TransactionStore) -> StepResult {
        let result = tabStep(.setTabs(tabs), in: store)
        guard case .changed = result else {
            return result
        }
        let next = routers(for: tabs)
        updateWorkingCopy { snapshot in
            snapshot.withTabRouters(next)
        }
        return result
    }

    /// Applies a tab command to the working copy.
    func tabStep(_ command: TabCommand<Tab>, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        switch TabReducer.reduce(current.state, command) {
        case .changed(let next, let changes):
            return apply(next, changes, in: store)
        case .unchanged:
            return .unchanged
        case .rejected(let rejection):
            return .failed(draft(rejection))
        }
    }

    /// The existing router of each kept tab, and a new one for each new tab.
    private func routers(for tabs: [Tab]) -> [Tab: StackRouter] {
        let existing = current.tabRouters
        let pairs = tabs.map { tab in
            (tab, existing[tab] ?? newTabRouter(for: tab))
        }
        return Dictionary(pairs) { first, _ in
            first
        }
    }

    /// A router for a tab added by `setTabs`. It joins the tree when the transaction commits.
    private func newTabRouter(for tab: Tab) -> StackRouter {
        let flow = tree.claimFlowName(DescriptionFormat.name(of: tab))
        return StackRouter(tabOf: self, flow: flow, isAttached: false)
    }

    /// Stores the reduced state and records its changes.
    private func apply(_ next: TabState<Tab>, _ changes: [NavigationChange], in store: TransactionStore) -> StepResult {
        updateWorkingCopy { snapshot in
            snapshot.withState(next)
        }
        store.record(changes, in: flowID)
        return .changed
    }
}
