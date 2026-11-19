//
//  StackRouter+Tree.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
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

    /// Whether the stack was made with a root route.
    var showsRootRoute: Bool {
        rootRoute != nil
    }

    /// `shop      Product list (…)`, with the presented flow below.
    func readableTree(_ naming: RouteNaming) -> ReadableTree {
        let stack = ReadableLog.Stack(routes: shownRoutes, startsWithRootRoute: showsRootRoute)
        let detail = ReadableLog.stackText(stack, naming: naming, shortens: false)
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

    /// Pushes routes after checking each has a destination, unless the duplicate push rule
    /// skips them.
    func pushStep(_ routes: [AnyRoute], in store: TransactionStore) -> StepResult {
        if let missing = routes.first(where: { !tree.hasDestination(for: $0) }) {
            return .failed(unregisteredDraft(missing))
        }
        if let skipped = duplicateOfPushInFlight(routes) {
            store.noteSkippedPush(skipped)
            return .unchanged
        }
        return stackStep(.pushMany(routes), in: store)
    }

    /// The route of a push that repeats the one still being pushed, or `nil` when the push goes
    /// ahead. Only a push of one route that equals the route in flight, still on top, repeats it.
    private func duplicateOfPushInFlight(_ routes: [AnyRoute]) -> AnyRoute? {
        guard duplicatePushRule == .skipWhileInFlight, let inFlight = pushInFlight else {
            return nil
        }
        guard routes == [inFlight], currentPath.last == inFlight else {
            return nil
        }
        return inFlight
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
