//
//  NavigationTreeContext.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What the routers of one tree share: the route registry, the queue of re-entrant calls and
/// the flow names in use. The root router creates it, and every router inside gets the same one.
@MainActor
final class NavigationTreeContext {
    /// The tree's settings, given once to the root router, with every route type registered
    /// since.
    ///
    /// `var` because destinations are registered one by one as renderers and coordinators set
    /// up, and a renderer may install the platform's log handler. Only ``register(_:)`` changes
    /// its registry, and only ``installDefaultLogHandler(_:)`` its log handler.
    private(set) var configuration: NavigationConfiguration

    /// The seams for observers, logging, strict mode and the failure handlers.
    ///
    /// `var` because observers join after the tree exists. Only the `on…` functions and
    /// ``addFailureHandler(_:)`` change it.
    private var observers: Observers

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

    /// How many pushed screens were given an id, for each screen's id.
    ///
    /// `var` because each pushed screen takes the next id. Only ``claimScreenID()`` changes it.
    private var screenCount: UInt64 = 0

    /// The time on the tree's clock, for the journey's durations and duplicate window.
    ///
    /// `var` because tests set a clock they move by hand. Only tests change it.
    var journeyClock: () -> Duration

    /// Why a setting given to the tree was replaced by its default, or `nil`.
    let configurationProblem: String?

    /// The screen on display and the journey that led to it.
    let journey = JourneyTracker()

    /// A presentation's box, held until the presented stack is drawn, or `nil`.
    ///
    /// `var` because each presentation holds its box. Only `trackJourney` and
    /// `flushHeldJourney()` change it.
    private var heldJourney: HeldJourney?

    /// Whether a renderer names views, so a presentation's box waits for its view's name.
    ///
    /// `var` because it turns on when a renderer first names a view. Only
    /// `StackRouter.setRootViewName(_:)` and `registerViewName(_:for:)` change it.
    var namesViews = false

    /// The name of the view that draws each route type, as renderers registered them, for the
    /// journey box.
    ///
    /// `var` because renderers register destinations as they draw. Only
    /// `StackRouter.registerViewName(_:for:)` changes it.
    var viewNames: [RouteKey: String] = [:]

    /// Route types registered for decoding and as having a destination.
    var registry: RouteRegistry {
        configuration.registry
    }

    /// How the tree logs. Default: ``LogConfiguration/default``.
    var logging: LogConfiguration {
        configuration.logging
    }

    /// The most calls that may be queued in one main-actor turn. Default: 32.
    var maxQueuedChanges: Int {
        configuration.maxQueuedChanges
    }

    /// A tree with these settings. A setting that can't be used is replaced by its default, and
    /// ``configurationProblem`` says why, so the root router can report it once it exists.
    init(configuration: NavigationConfiguration) {
        let checked = configuration.validated()
        self.configuration = checked.configuration
        self.configurationProblem = checked.problem
        self.observers = Observers()
        let start = ContinuousClock.now
        self.journeyClock = {
            ContinuousClock.now - start
        }
        if let handler = configuration.onNavigationFailure {
            addFailureHandler { failure in
                handler(failure)
            }
        }
        for problem in configuration.registry.problems {
            logRegistryProblem(problem)
        }
    }

    /// Registers a route type for decoding and as having a destination.
    func register<R: Route>(_ type: R.Type) {
        let known = registry.problems.count
        configuration = configuration.withRegistry(registry.registering(type))
        for problem in registry.problems.dropFirst(known) {
            logRegistryProblem(problem)
        }
    }

    /// Writes the tree's logs to `makeHandler()` when the app gave no handler, so a renderer can
    /// make the unified log the default. A handler the app chose, `.disabled` included, is kept,
    /// and a tree that already has one installed keeps it. Returns whether it was installed.
    @discardableResult
    func installDefaultLogHandler(_ makeHandler: () -> any LogHandler) -> Bool {
        guard logging.usesDefaultHandler else {
            return false
        }
        configuration = configuration.withLogging(logging.withHandler(makeHandler()))
        return true
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

    /// Whether a route may be shown: any route when the registry is permissive, otherwise only
    /// a registered type.
    func hasDestination(for route: AnyRoute) -> Bool {
        registry.allows(route)
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

    /// The id of the next pushed screen. Ids start at 1; 0 is every stack's root screen.
    func claimScreenID() -> UInt64 {
        screenCount += 1
        return screenCount
    }

    /// The id of the next measured interval.
    func claimIntervalID() -> UInt64 {
        intervalCount += 1
        return intervalCount
    }

    /// Runs one call as a transaction on `router`.
    ///
    /// A router that left the tree ignores the call, and so does a call whose `isLive` says its
    /// caller is gone, such as a navigator whose screen was popped. Both are checked again when a
    /// queued call runs. A call made while another transaction is
    /// applied waits in the queue and returns `.queued`. Otherwise the body changes working
    /// copies, which are committed together, or all rolled back when the call fails.
    func perform(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        trigger: String? = nil,
        isLive: @escaping () -> Bool = { true },
        _ body: @escaping (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        let outcome = start(on: router, file: file, line: line, trigger: trigger, isLive: isLive, body)
        observers.finished?(outcome)
        return outcome
    }

    /// Ignores, queues or applies a call.
    private func start(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        trigger: String?,
        isLive: @escaping () -> Bool,
        _ body: @escaping (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        guard router.isAttached, isLive() else {
            logIgnored(router.flowID, file: file, line: line)
            return .ignored
        }
        guard !turn.isApplying else {
            return enqueue(on: router, file: file, line: line, trigger: trigger, isLive: isLive, body)
        }
        let outcome = apply(on: router, file: file, line: line, trigger: trigger, body)
        drainQueue()
        RouterTable.shared.sweep()
        return outcome
    }

    /// Applies the body as one transaction, measured as one interval. Issues are logged before
    /// the changes, so a recovered issue reads before what its fallback did, and observers hear
    /// of them after the commit.
    private func apply(
        on router: some TreeNode,
        file: StaticString,
        line: UInt,
        trigger: String?,
        _ body: (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        turn = turn.applying(true)
        let interval = beginTransactionInterval()
        defer {
            endTransactionInterval(interval)
            turn = turn.applying(false)
        }
        flushHeldJourney()
        let store = TransactionStore(trigger: trigger)
        let result = body(store)
        logIssues(store.issues)
        let outcome = finish(store, result, on: router, file: file, line: line)
        for (issue, _) in store.issues {
            observers.reported?(issue)
        }
        logUnchanged(outcome, flow: router.flowID, skippedPush: store.skippedPush, file: file, line: line)
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

    /// Commits the working copies, logs the changes and the journey, and tells the observers.
    private func commit(
        _ store: TransactionStore,
        outcome: NavigationOutcome,
        on router: some TreeNode,
        file: StaticString,
        line: UInt
    ) -> NavigationOutcome {
        store.commit()
        logChanges(store.changes, in: router, file: file, line: line)
        trackJourney(store.changes, in: router, trigger: store.trigger, file: file, line: line)
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

    /// Ignores a call made through a navigator whose router was released or whose screen was
    /// popped, or on a transaction kept past its call: logs `staleNavigator` and tells the
    /// observers, as for a router that left the tree.
    func ignoreStale(_ flow: FlowID, file: StaticString, line: UInt) -> NavigationOutcome {
        logIgnored(flow, file: file, line: line)
        observers.finished?(.ignored)
        return .ignored
    }

    /// Works out the screen on display after a change, or when a stack first appears, and logs
    /// what the journey writes for it.
    func trackJourney(
        _ changes: [AppliedChange],
        in router: some TreeNode,
        trigger: String?,
        file: StaticString,
        line: UInt
    ) {
        let change = JourneyChange(
            changes: changes,
            trigger: trigger,
            callSite: Self.callSite(file, line),
            time: journeyClock(),
            duplicateWindow: logging.duplicateScreenWindow
        )
        flushHeldJourney()
        let root = router.rootNode
        let entries = journey.track(change, in: root)
        guard let flow = flowAwaitingItsView(entries, in: root) else {
            logJourney(entries, root: root, file: file, line: line)
            return
        }
        heldJourney = HeldJourney(entries: entries, root: root, flow: flow, file: file, line: line)
    }

    /// The flow a change presented whose first screen has no view name yet, when renderers name
    /// views: its box waits until the flow's stack is drawn, so it names the view.
    private func flowAwaitingItsView(_ entries: [JourneyEntry], in root: any TreeNode) -> FlowID? {
        guard namesViews, let visible = VisibleScreen(in: root), visible.screen.viewName == nil else {
            return nil
        }
        let started = entries.contains { entry in
            guard case .flowStarted(let flow) = entry else {
                return false
            }
            return flow.flow == visible.screen.flow
        }
        return started ? visible.screen.flow : nil
    }

    /// Writes the box a presentation held, before the next change or once its stack is drawn.
    func flushHeldJourney() {
        guard let held = heldJourney else {
            return
        }
        heldJourney = nil
        logJourney(held.entries, root: held.root, file: held.file, line: held.line)
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
        trigger: String?,
        isLive: @escaping () -> Bool,
        _ body: @escaping (TransactionStore) -> CallResult
    ) -> NavigationOutcome {
        guard turn.queuedCount < maxQueuedChanges else {
            return refuseLoop(on: router, file: file, line: line)
        }
        logQueued(router.flowID, file: file, line: line)
        turn = turn.enqueuing { [unowned self] in
            _ = self.perform(on: router, file: file, line: line, trigger: trigger, isLive: isLive, body)
        }
        return .queued
    }

    /// Reports `reentrantLoop` for the first call past `maxQueuedChanges` in a turn, and drops
    /// the rest.
    ///
    /// The failure handlers hear the first one only. A handler that navigates would otherwise be
    /// refused again, call the handler again, and never return (#24).
    private func refuseLoop(on router: some TreeNode, file: StaticString, line: UInt) -> NavigationOutcome {
        let message = "More than \(maxQueuedChanges) calls were made while changes were applied, "
            + "which looks like an observer that navigates on every change. The rest were dropped."
        let issue = NavigationIssue(kind: .reentrantLoop, flow: router.flowID, message: message, file: file, line: line)
        let failure = NavigationFailure(issue: issue)
        guard !turn.hasRefusedLoop else {
            return .failed(failure)
        }
        turn = turn.refusingLoop()
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

/// A box the journey wrote for a presentation, waiting for the presented stack to be drawn.
struct HeldJourney {
    /// What the journey wrote.
    let entries: [JourneyEntry]

    /// The root of the tree.
    let root: any TreeNode

    /// The presented flow whose stack the box waits for.
    let flow: FlowID

    /// The call's file.
    let file: StaticString

    /// The call's line.
    let line: UInt
}
