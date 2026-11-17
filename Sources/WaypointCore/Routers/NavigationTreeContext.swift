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

    /// How the tree logs.
    var logging = LogConfiguration.default

    /// The id of the next measured interval.
    var nextIntervalID: UInt64 = 0

    /// Called with the changes of each committed transaction, while it is still being applied.
    /// The seam for observers and events (#23).
    var didApply: (([AppliedChange]) -> Void)?

    /// Called with each issue when it is reported. The seam for observers and logging.
    var didReport: ((NavigationIssue) -> Void)?

    /// Called with the outcome of every call, including queued and ignored ones. The seam for
    /// `WaypointTesting` strict mode (#41).
    package var didFinish: ((NavigationOutcome) -> Void)?

    /// The app's handlers for calls that failed and could not be recovered.
    private var failureHandlers: [(NavigationFailure) -> Void] = []

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
        let known = registry.problems.count
        registry.register(type)
        checksDestinations = true
        for problem in registry.problems.dropFirst(known) {
            logRegistryProblem(problem)
        }
    }

    /// Whether a route may be shown: always before any registration, then only when its type is
    /// registered.
    func hasDestination(for route: AnyRoute) -> Bool {
        guard checksDestinations else {
            return true
        }
        return registry.type(for: route.routeKey) != nil
    }

    /// Adds a handler for calls that failed and could not be recovered.
    func addFailureHandler(_ handler: @escaping (NavigationFailure) -> Void) {
        failureHandlers.append(handler)
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
    /// copies, which are committed together, or all rolled back when the call fails.
    func perform(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        _ body: @escaping (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        let outcome = start(on: router, file: file, line: line, body)
        didFinish?(outcome)
        return outcome
    }

    /// Ignores, queues or applies a call.
    private func start(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        _ body: @escaping (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        guard router.isAttached else {
            logIgnored(router.flowID, file: file, line: line)
            return .ignored
        }
        guard !isApplying else {
            return enqueue(on: router, file: file, line: line, body)
        }
        let outcome = apply(on: router.flowID, file: file, line: line, body)
        drainQueue()
        return outcome
    }

    /// Applies the body as one transaction, measured as one interval.
    private func apply(
        on flow: FlowID,
        file: StaticString,
        line: UInt,
        _ body: (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        isApplying = true
        let interval = beginTransactionInterval()
        defer {
            endTransactionInterval(interval)
            isApplying = false
        }
        let store = TransactionStore()
        let outcome = finish(store, body(store), file: file, line: line)
        for (issue, level) in store.issues {
            report(issue, level: level)
        }
        logUnchanged(outcome, flow: flow, file: file, line: line)
        return outcome
    }

    /// Commits or rolls back, depending on the result.
    private func finish(
        _ store: TransactionStore,
        _ result: CallResult,
        file: StaticString,
        line: UInt
    ) -> NavigationOutcome {
        switch result {
        case .changed:
            return commit(store, outcome: .applied, file: file, line: line)
        case .unchanged:
            return rollBack(store, outcome: .alreadyThere)
        case .recovered(let issue, let fallback):
            return commit(store, outcome: .recovered(issue, by: fallback), file: file, line: line)
        case .failed(let failure):
            return fail(store, failure)
        }
    }

    /// Commits the working copies, logs the changes and tells the observers.
    private func commit(
        _ store: TransactionStore,
        outcome: NavigationOutcome,
        file: StaticString,
        line: UInt
    ) -> NavigationOutcome {
        store.commit()
        logChanges(store.changes, file: file, line: line)
        if !store.changes.isEmpty {
            didApply?(store.changes)
        }
        return outcome
    }

    /// Drops the working copies.
    private func rollBack(_ store: TransactionStore, outcome: NavigationOutcome) -> NavigationOutcome {
        store.rollback()
        return outcome
    }

    /// Rolls the transaction back and tells the app's failure handlers.
    private func fail(_ store: TransactionStore, _ failure: NavigationFailure) -> NavigationOutcome {
        store.rollback()
        for handler in failureHandlers {
            handler(failure)
        }
        return .failed(failure)
    }

    /// Reports an issue to the observers and logs it in the `issues` category.
    func report(_ issue: NavigationIssue, level: LogLevel) {
        didReport?(issue)
        logIssue(issue, level: level)
    }

    /// Queues a call, or refuses it when too many were queued in this turn.
    private func enqueue(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        _ body: @escaping (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        guard queuedInTurn < maxQueuedChanges else {
            return refuseLoop(on: router, file: file, line: line)
        }
        queuedInTurn += 1
        logQueued(router.flowID, file: file, line: line)
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
        let failure = NavigationFailure(issue: issue)
        report(issue, level: .fault)
        for handler in failureHandlers {
            handler(failure)
        }
        return .failed(failure)
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
