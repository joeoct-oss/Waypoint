//
//  TabRouter+Tree.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
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
}

/// Conformances:
/// - `TransactionParticipant`, so a transaction can change it on a working copy.
extension TabRouter: TransactionParticipant {
    /// Copies the state, the presented router and the tab routers.
    func beginWorkingCopy() {
        working = Working(state: state, presented: presented, tabRouters: tabRouters)
    }

    /// Writes the state once, and swaps routers that changed.
    func commitWorkingCopy() {
        guard let working else {
            return
        }
        self.working = nil
        if working.state != state {
            state = working.state
        }
        commitTabRouters(working.tabRouters)
        commitPresented(working.presented)
    }

    /// Drops the working copy, and frees the names of routers that never joined.
    func discardWorkingCopy() {
        guard let working else {
            return
        }
        self.working = nil
        let created = working.tabRouters.values.filter { router in
            !tabRouters.values.contains { $0 === router }
        }
        let presentedCreated = working.presented.flatMap { $0 === presented ? nil : $0 }
        for router in created + (presentedCreated.map { [$0] } ?? []) {
            tree.releaseFlowName(router.flowID)
        }
    }

    /// Detaches removed tab routers and attaches new ones.
    private func commitTabRouters(_ next: [Tab: StackRouter]) {
        for (tab, router) in tabRouters where next[tab] !== router {
            router.detachSubtree()
        }
        for router in next.values {
            router.isAttached = true
        }
        tabRouters = next
    }

    /// Swaps the presented router if it changed.
    private func commitPresented(_ next: StackRouter?) {
        guard next !== presented else {
            return
        }
        presented?.detachSubtree()
        presented = next
        presented?.isAttached = true
    }
}

/// Conformances:
/// - `PresentingRouter`, so it can present a flow above all its tabs.
extension TabRouter: PresentingRouter {
    /// The working copy's presentation.
    var workingPresentation: Presentation? {
        get {
            working?.state.presentation
        }
        set {
            working?.state.presentation = newValue
        }
    }

    /// The working copy's presented router.
    var workingPresented: StackRouter? {
        get {
            working?.presented
        }
        set {
            working?.presented = newValue
        }
    }

    /// Each tab's router, which is inside this flow.
    var workingInFlowChildren: [any PresentingRouter] {
        guard let working else {
            return []
        }
        return working.state.tabs.compactMap { working.tabRouters[$0] }
    }
}

extension TabRouter {
    /// Selects a tab, or pops the selected tab's stack when it is selected again.
    func selectStep(_ tab: Tab, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        guard let working else {
            return .unchanged
        }
        guard tab == working.state.selection, popsToRootOnReselect, let stack = working.tabRouters[tab] else {
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
        working?.tabRouters = next
        return result
    }

    /// Applies a tab command to the working copy.
    private func tabStep(_ command: TabCommand<Tab>, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        guard let current = working?.state else {
            return .unchanged
        }
        switch TabReducer.reduce(current, command) {
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
        let existing = working?.tabRouters ?? tabRouters
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
        working?.state = next
        store.record(changes, in: flowID)
        return .changed
    }
}
