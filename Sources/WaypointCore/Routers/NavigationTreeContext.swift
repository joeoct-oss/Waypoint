//
//  NavigationTreeContext.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What the routers of one tree share: the route registry, the queue of re-entrant calls and
/// the flow names in use. The root router creates it, and every router inside gets the same one.
@MainActor
final class NavigationTreeContext {
    /// Route types registered for decoding and as having a destination.
    private(set) var registry = RouteRegistry()

    /// Whether pushes check that the route type has a destination. Turned on by the first
    /// registration, so a tree without destinations, such as one in a unit test, is not checked.
    private(set) var checksDestinations = false

    /// The most calls that may be queued in one main-actor turn. Default: 32.
    var maxQueuedChanges = 32

    /// Called with the changes of each committed transaction, while it is still being applied.
    /// The seam for observers and events (#23).
    var didApply: (([AppliedChange]) -> Void)?

    /// Called with each issue when it is reported. The seam for observers and logging.
    var didReport: ((NavigationIssue) -> Void)?

    /// Whether a transaction is being applied, including its observers.
    private var isApplying = false

    /// Whether queued calls are running.
    private var isDraining = false

    /// Calls made while a transaction was applied, in order.
    private var queue: [() -> Void] = []

    /// Calls queued since the queue was last empty.
    private var queuedInTurn = 0

    /// Flow names used by routers in the tree.
    private var flowNames: Set<String> = []

    /// Registers a route type for decoding and as having a destination.
    func register<R: Route>(_ type: R.Type) {
        registry.register(type)
        checksDestinations = true
    }

    /// Whether a route may be shown: always before any registration, then only when its type is
    /// registered.
    func hasDestination(for route: AnyRoute) -> Bool {
        guard checksDestinations else {
            return true
        }
        return registry.type(for: route.routeKey) != nil
    }

    /// Claims a flow name, adding `-2`, `-3` and so on when it is taken.
    func claimFlowName(_ base: String) -> FlowID {
        var name = base
        var number = 1
        while flowNames.contains(name) {
            number += 1
            name = "\(base)-\(number)"
        }
        flowNames.insert(name)
        return FlowID(name)
    }

    /// Frees a flow name when its router leaves the tree.
    func releaseFlowName(_ flow: FlowID) {
        flowNames.remove(flow.name)
    }

    /// Runs one call as a transaction on `router`.
    ///
    /// A router that left the tree ignores the call. A call made while another transaction is
    /// applied waits in the queue and returns `.queued`. Otherwise the body changes working
    /// copies, which are committed together, or all rolled back when a step fails.
    func perform(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        _ body: @escaping (TransactionStore) -> StepResult
    ) -> NavigationOutcome {
        guard router.isAttached else {
            return .ignored
        }
        guard !isApplying else {
            return enqueue(on: router, file: file, line: line, body)
        }
        let outcome = apply(file: file, line: line, body)
        drainQueue()
        return outcome
    }

    /// Applies the body as one transaction.
    private func apply(file: StaticString, line: UInt, _ body: (TransactionStore) -> StepResult) -> NavigationOutcome {
        isApplying = true
        defer {
            isApplying = false
        }
        let store = TransactionStore()
        switch body(store) {
        case .changed:
            return commit(store)
        case .unchanged:
            return finishUnchanged(store)
        case .failed(let draft):
            return fail(store, draft.issue(file: file, line: line))
        }
    }

    /// Commits the working copies and tells the observers.
    private func commit(_ store: TransactionStore) -> NavigationOutcome {
        store.commit()
        didApply?(store.changes)
        return .applied
    }

    /// Drops the working copies of a transaction that changed nothing.
    private func finishUnchanged(_ store: TransactionStore) -> NavigationOutcome {
        store.rollback()
        return .alreadyThere
    }

    /// Rolls the transaction back and reports the issue.
    private func fail(_ store: TransactionStore, _ issue: NavigationIssue) -> NavigationOutcome {
        store.rollback()
        report(issue)
        return .failed(NavigationFailure(issue: issue))
    }

    /// Reports an issue.
    func report(_ issue: NavigationIssue) {
        didReport?(issue)
    }

    /// Queues a call, or refuses it when too many were queued in this turn.
    private func enqueue(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        _ body: @escaping (TransactionStore) -> StepResult
    ) -> NavigationOutcome {
        guard queuedInTurn < maxQueuedChanges else {
            return refuseLoop(on: router, file: file, line: line)
        }
        queuedInTurn += 1
        queue.append { [unowned self] in
            _ = self.perform(on: router, file: file, line: line, body)
        }
        return .queued
    }

    /// Reports `reentrantLoop` for a call past `maxQueuedChanges`.
    private func refuseLoop(on router: some TreeNode, file: StaticString, line: UInt) -> NavigationOutcome {
        let message = "More than \(maxQueuedChanges) calls were made while changes were applied, "
            + "which looks like an observer that navigates on every change. The rest were dropped."
        let issue = NavigationIssue(kind: .reentrantLoop, flow: router.flowID, message: message, file: file, line: line)
        report(issue)
        return .failed(NavigationFailure(issue: issue))
    }

    /// Runs queued calls in order until none are left. Only the outermost call drains.
    private func drainQueue() {
        guard !isDraining else {
            return
        }
        isDraining = true
        while !queue.isEmpty {
            let call = queue.removeFirst()
            call()
        }
        isDraining = false
        queuedInTurn = 0
    }
}
