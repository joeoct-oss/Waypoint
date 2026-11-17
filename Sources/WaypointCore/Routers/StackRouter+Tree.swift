//
//  StackRouter+Tree.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Conformances:
/// - `TreeNode`, so the tree can walk, detach and inherit through it.
extension StackRouter: TreeNode {
    /// The committed presented flow.
    var presentedNode: (any TreeNode)? {
        presented
    }

    /// The presented flow, if any.
    var childNodes: [any TreeNode] {
        presented.map { [$0] } ?? []
    }

    /// The path as it is in the current transaction, or the committed one.
    var currentPath: [AnyRoute] {
        current.state.path
    }

    /// This stack.
    var shownStack: any TreeNode {
        self
    }

    /// The root route, if any, then the path.
    var shownRoutes: [AnyRoute] {
        (rootRoute.map { [$0] } ?? []) + current.state.path
    }

    /// `shop      Product list (…)`, with the presented flow below.
    func readableTree(_ naming: RouteNaming) -> ReadableTree {
        let detail = ReadableLog.stackText(shownRoutes, naming: naming)
        let style = current.state.presentation?.style
        let children = presented.map { child in
            [child.readableTree(naming).presented(as: style)]
        }
        return ReadableTree(name: flowID.name, detail: detail, children: children ?? [])
    }
}

/// Conformances:
/// - `PresentingRouter`, so it can present and dismiss a child flow.
extension StackRouter: PresentingRouter {
    /// The working copy's presentation.
    var workingPresentation: Presentation? {
        current.state.presentation
    }

    /// The presented router as it is in the current transaction, or the committed one.
    var currentPresented: StackRouter? {
        current.presented
    }

    /// This stack.
    var visibleStack: StackRouter? {
        self
    }

    /// A stack has no routers inside its own flow.
    var workingInFlowChildren: [any PresentingRouter] {
        []
    }

    /// Presents a flow in the working copy, or clears it with `nil`.
    func updateWorkingPresentation(_ presentation: Presentation?, presented router: StackRouter?) {
        updateWorkingCopy { snapshot in
            snapshot.presenting(presentation, by: router)
        }
    }
}

extension StackRouter {
    /// Applies a stack command to the working copy.
    func stackStep(_ command: StackCommand, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        switch StackReducer.reduce(current.state, command, rootRoute: rootRoute) {
        case .changed(let next, let changes):
            return apply(next, changes, in: store)
        case .unchanged:
            return .unchanged
        case .rejected(let rejection):
            return .failed(draft(rejection))
        }
    }

    /// Pushes routes after checking each has a destination.
    func pushStep(_ routes: [AnyRoute], in store: TransactionStore) -> StepResult {
        if let missing = routes.first(where: { !tree.hasDestination(for: $0) }) {
            return .failed(unregisteredDraft(missing))
        }
        return stackStep(.pushMany(routes), in: store)
    }

    /// Stores the reduced state and records its changes.
    private func apply(_ next: StackState, _ changes: [NavigationChange], in store: TransactionStore) -> StepResult {
        updateWorkingCopy { snapshot in
            snapshot.withState(next)
        }
        store.record(changes, in: flowID)
        return .changed
    }
}
