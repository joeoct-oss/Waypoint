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

    /// The committed path.
    var currentPath: [AnyRoute] {
        working?.state.path ?? state.path
    }
}

/// Conformances:
/// - `TransactionParticipant`, so a transaction can change it on a working copy.
extension StackRouter: TransactionParticipant {
    /// Copies the state and the presented router.
    func beginWorkingCopy() {
        working = Working(state: state, presented: presented)
    }

    /// Writes the state once, and swaps the presented router if it changed.
    func commitWorkingCopy() {
        guard let working else {
            return
        }
        self.working = nil
        if working.state != state {
            state = working.state
        }
        guard working.presented !== presented else {
            return
        }
        presented?.detachSubtree()
        presented = working.presented
        presented?.isAttached = true
    }

    /// Drops the working copy, and frees the name of a presented router that never joined.
    func discardWorkingCopy() {
        if let created = working?.presented, created !== presented {
            tree.releaseFlowName(created.flowID)
        }
        working = nil
    }
}

/// Conformances:
/// - `PresentingRouter`, so it can present and dismiss a child flow.
extension StackRouter: PresentingRouter {
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

    /// The presented router as it is in the current transaction, or the committed one.
    var currentPresented: StackRouter? {
        guard let working else {
            return presented
        }
        return working.presented
    }

    /// This stack.
    var visibleStack: StackRouter? {
        self
    }

    /// A stack has no routers inside its own flow.
    var workingInFlowChildren: [any PresentingRouter] {
        []
    }
}

extension StackRouter {
    /// Applies a stack command to the working copy.
    func stackStep(_ command: StackCommand, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        guard let current = working?.state else {
            return .unchanged
        }
        switch StackReducer.reduce(current, command, rootRoute: rootRoute) {
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
        working?.state = next
        store.record(changes, in: flowID)
        return .changed
    }
}
