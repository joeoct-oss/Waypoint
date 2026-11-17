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
    ///
    /// `var` because destinations are registered one by one as renderers and coordinators set
    /// up. Only ``register(_:)`` changes it.
    private(set) var registry = RouteRegistry()

    /// How the tree logs, and how many calls may be queued in one turn.
    ///
    /// `var` because the app and renderers set them after the root router exists. Only
    /// ``setLogging(_:)`` and ``setMaxQueuedChanges(_:)`` change it.
    private var settings = Settings()

    /// The seams for observers, logging, strict mode and the app's failure handlers.
    ///
    /// `var` because observers join after the tree exists. Only the `on…` functions and
    /// ``addFailureHandler(_:)`` change it.
    private var observers = Observers()

    /// Whether a transaction is being applied or queued calls are running, and the queue.
    ///
    /// `var` because it follows each call through the main-actor turn. Only `start`, `apply`,
    /// `enqueue` and `drainQueue` change it.
    private var turn = Turn.idle

    /// Flow names used by routers in the tree.
    ///
    /// `var` because flows come and go. Only ``claimFlowName(_:)`` and ``releaseFlowName(_:)``
    /// change it.
    private var flowNames: Set<String> = []

    /// How many transaction intervals were measured, for each interval's id.
    ///
    /// `var` because each measured transaction takes the next id. Only ``claimIntervalID()``
    /// changes it.
    private var intervalCount: UInt64 = 0

    /// Whether pushes check that the route type has a destination. Turned on by the first
    /// registration, so a tree without destinations, such as one in a unit test, is not checked.
    var checksDestinations: Bool {
        !registry.isEmpty
    }

    /// How the tree logs. Default: ``LogConfiguration/default``.
    var logging: LogConfiguration {
        settings.logging
    }

    /// The most calls that may be queued in one main-actor turn. Default: 32.
    var maxQueuedChanges: Int {
        settings.maxQueuedChanges
    }

    /// Registers a route type for decoding and as having a destination.
    func register<R: Route>(_ type: R.Type) {
        let known = registry.problems.count
        registry = registry.registering(type)
        for problem in registry.problems.dropFirst(known) {
            logRegistryProblem(problem)
        }
    }

    /// Sets how the tree logs.
    func setLogging(_ configuration: LogConfiguration) {
        settings = settings.withLogging(configuration)
    }

    /// Sets the queue limit, or returns why it can't: a limit below 1 would drop every call
    /// made from an observer.
    func setMaxQueuedChanges(_ limit: Int) -> String? {
        guard limit >= 1 else {
            return "maxQueuedChanges must be at least 1, so \(limit) was not set. "
                + "It stays \(settings.maxQueuedChanges)."
        }
        settings = settings.withMaxQueuedChanges(limit)
        return nil
    }

    /// Calls `observer` with the changes of each committed transaction, while it is still being
    /// applied. The seam for observers and events (#23). Replaces the previous one.
    func onApplied(_ observer: @escaping ([AppliedChange]) -> Void) {
        observers = observers.withApplied(observer)
    }

    /// Calls `observer` with each issue when it is reported. The seam for observers and
    /// logging. Replaces the previous one.
    func onReported(_ observer: @escaping (NavigationIssue) -> Void) {
        observers = observers.withReported(observer)
    }

    /// Calls `observer` with the outcome of every call, including queued and ignored ones. The
    /// seam for `WaypointTesting` strict mode (#41). Replaces the previous one.
    package func onFinished(_ observer: @escaping (NavigationOutcome) -> Void) {
        observers = observers.withFinished(observer)
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
        observers = observers.addingFailureHandler(handler)
    }

    /// Claims a flow name, adding `-2`, `-3` and so on when it is taken.
    func claimFlowName(_ base: String) -> FlowID {
        let candidates = sequence(first: 1) { $0 + 1 }.lazy.map { number in
            number == 1 ? base : "\(base)-\(number)"
        }
        let name = candidates.first { !flowNames.contains($0) } ?? base
        flowNames.insert(name)
        return FlowID(name)
    }

    /// Frees a flow name when its router leaves the tree.
    func releaseFlowName(_ flow: FlowID) {
        flowNames.remove(flow.name)
    }

    /// The id of the next measured interval.
    func claimIntervalID() -> UInt64 {
        intervalCount += 1
        return intervalCount
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
        observers.finished?(outcome)
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
        guard !turn.isApplying else {
            return enqueue(on: router, file: file, line: line, body)
        }
        let outcome = apply(on: router, file: file, line: line, body)
        drainQueue()
        return outcome
    }

    /// Applies the body as one transaction, measured as one interval. Issues are logged before
    /// the changes, so a recovered issue reads before what its fallback did, and observers hear
    /// of them after the commit.
    private func apply(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        _ body: (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        turn = turn.applying(true)
        let interval = beginTransactionInterval()
        defer {
            endTransactionInterval(interval)
            turn = turn.applying(false)
        }
        let store = TransactionStore()
        let result = body(store)
        logIssues(store.issues)
        let outcome = finish(store, result, on: router, file: file, line: line)
        for (issue, _) in store.issues {
            observers.reported?(issue)
        }
        logUnchanged(outcome, flow: router.flowID, file: file, line: line)
        return outcome
    }

    /// Commits or rolls back, depending on the result.
    private func finish(
        _ store: TransactionStore,
        _ result: CallResult,
        on router: some TreeNode,
        file: StaticString,
        line: UInt
    ) -> NavigationOutcome {
        switch result {
        case .changed:
            return commit(store, outcome: .applied, on: router, file: file, line: line)
        case .unchanged:
            return rollBack(store, outcome: .alreadyThere)
        case .recovered(let issue, let fallback):
            return commit(store, outcome: .recovered(issue, by: fallback), on: router, file: file, line: line)
        case .failed(let failure):
            return fail(store, failure)
        }
    }

    /// Commits the working copies, logs the changes and tells the observers.
    private func commit(
        _ store: TransactionStore,
        outcome: NavigationOutcome,
        on router: some TreeNode,
        file: StaticString,
        line: UInt
    ) -> NavigationOutcome {
        store.commit()
        logChanges(store.changes, in: router, file: file, line: line)
        if !store.changes.isEmpty {
            observers.applied?(store.changes)
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
        for handler in observers.failureHandlers {
            handler(failure)
        }
        return .failed(failure)
    }

    /// Reports an issue to the observers and logs it in the `issues` category.
    func report(_ issue: NavigationIssue, level: LogLevel) {
        observers.reported?(issue)
        logIssue(issue, level: level)
    }

    /// Queues a call, or refuses it when too many were queued in this turn.
    private func enqueue(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        _ body: @escaping (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        guard turn.queuedCount < maxQueuedChanges else {
            return refuseLoop(on: router, file: file, line: line)
        }
        logQueued(router.flowID, file: file, line: line)
        turn = turn.enqueuing { [unowned self] in
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
        for handler in observers.failureHandlers {
            handler(failure)
        }
        return .failed(failure)
    }

    /// Runs queued calls in order until none are left. Only the outermost call drains.
    private func drainQueue() {
        guard !turn.isDraining else {
            return
        }
        turn = turn.draining(true)
        while let call = takeNextQueuedCall() {
            call()
        }
        turn = .idle
    }

    /// Removes the first queued call and returns it, or `nil` when the queue is empty.
    private func takeNextQueuedCall() -> (() -> Void)? {
        guard let call = turn.queue.first else {
            return nil
        }
        turn = turn.withQueue(Array(turn.queue.dropFirst()))
        return call
    }
}
