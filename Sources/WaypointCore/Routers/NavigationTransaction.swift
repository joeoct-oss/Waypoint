//
//  NavigationTransaction.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Several navigation changes applied as one.
///
/// A transaction has the same methods as the routers. They apply to working copies, which become
/// the state when the transaction's closure returns: each router's state changes once, the
/// renderer draws once, and observers get one batch. If any step fails, every step is rolled back
/// and the steps after it are skipped.
///
/// Each method returns the step's own outcome: `.applied`, `.alreadyThere`, or `.failed`, which
/// means the whole transaction will be rolled back.
///
/// Steps navigate the router the transaction was started on, or another router in the tree
/// through ``presented`` and ``router(for:)``.
@MainActor
public struct NavigationTransaction {
    /// The working copies and changes.
    private let store: TransactionStore

    /// The router this transaction value navigates, or `nil` when it names no router.
    private let target: (any PresentingRouter)?

    /// Why this value names no router, for steps made on it.
    private let missingTarget: IssueDraft?

    /// A transaction value on one router.
    init(store: TransactionStore, target: any PresentingRouter) {
        self.store = store
        self.target = target
        self.missingTarget = nil
    }

    /// A transaction value whose steps fail, because it names no router.
    private init(store: TransactionStore, missing: IssueDraft) {
        self.store = store
        self.target = nil
        self.missingTarget = missing
    }

    /// The flow presented by this transaction's router, as it is in the transaction so far.
    public var presented: NavigationTransaction? {
        target?.currentPresented.map { NavigationTransaction(store: store, target: $0) }
    }

    /// Runs a transaction's closure and sums up its steps.
    static func run(
        _ body: (inout NavigationTransaction) -> Void,
        on router: any PresentingRouter,
        in store: TransactionStore
    ) -> CallResult {
        var transaction = NavigationTransaction(store: store, target: router)
        body(&transaction)
        return store.transactionResult
    }

    /// Pushes one route.
    @discardableResult
    public func push<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let erased = AnyRoute(route)
        return onStack(context(fallback, file, line)) { stack in
            stack.pushStep([erased], in: store)
        }
    }

    /// Pushes several routes as one change.
    @discardableResult
    public func push(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        @RoutePathBuilder _ routes: () -> [AnyRoute]
    ) -> NavigationOutcome {
        let built = routes()
        return onStack(context(fallback, file, line)) { stack in
            stack.pushStep(built, in: store)
        }
    }

    /// Pops `count` routes.
    @discardableResult
    public func pop(
        count: Int = 1,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        onStack(context(fallback, file, line)) { stack in
            stack.stackStep(.pop(count: count), in: store)
        }
    }

    /// Pops to the last occurrence of `route`, or to the root when it is the root screen's route.
    @discardableResult
    public func popTo<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let erased = AnyRoute(route)
        return onStack(context(fallback, file, line, route: erased)) { stack in
            stack.stackStep(.popTo(erased), in: store)
        }
    }

    /// Pops to the last route of type `R` that matches `predicate`.
    @discardableResult
    public func popTo<R: Route>(
        _ type: R.Type,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        where predicate: (R) -> Bool = { _ in true }
    ) -> NavigationOutcome {
        onStack(context(fallback, file, line)) { stack in
            stack.popToStep(type, where: predicate, in: store)
        }
    }

    /// Empties the path.
    @discardableResult
    public func popToRoot(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        onStack(context(fallback, file, line)) { stack in
            stack.stackStep(.popToRoot, in: store)
        }
    }

    /// Replaces the whole path.
    @discardableResult
    public func setPath(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        @RoutePathBuilder _ routes: () -> [AnyRoute]
    ) -> NavigationOutcome {
        let built = routes()
        return onStack(context(fallback, file, line)) { stack in
            stack.setPathStep(built, in: store)
        }
    }

    /// Presents `route` as the root screen of a new child flow.
    @discardableResult
    public func present<R: Route>(
        _ route: R,
        style: PresentationStyle = .sheet,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let erased = AnyRoute(route)
        return onRouter(context(fallback, file, line)) { router in
            router.presentStep(erased, style: style, in: store)
        }
    }

    /// Dismisses the presented flow.
    @discardableResult
    public func dismiss(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        onRouter(context(fallback, file, line)) { router in
            router.dismissStep(in: store)
        }
    }

    /// Dismisses everything presented over this flow.
    @discardableResult
    public func dismissAll(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        onRouter(context(fallback, file, line)) { router in
            router.dismissAllStep(in: store)
        }
    }

    /// Asks whoever presented this flow to dismiss it.
    @discardableResult
    public func dismissFlow(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        onRouter(context(fallback, file, line)) { router in
            router.dismissFlowStep(in: store)
        }
    }

    /// Selects a tab. Fails with `unknownTab` unless this transaction's router is a tab
    /// container with that tab.
    ///
    /// Conformances:
    /// - `Tab: Hashable & Codable & Sendable`, the tab types a `TabRouter` accepts.
    @discardableResult
    public func select<Tab: Hashable & Codable & Sendable>(
        _ tab: Tab,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        onTabs(of: Tab.self, context(fallback, file, line)) { tabs in
            tabs.selectStep(tab, in: store)
        }
    }

    /// The transaction on one tab's stack, as it is in the transaction so far.
    ///
    /// Steps on it fail with `unknownTab` when this transaction's router isn't a tab container
    /// with that tab.
    ///
    /// Conformances:
    /// - `Tab: Hashable & Codable & Sendable`, the tab types a `TabRouter` accepts.
    public func router<Tab: Hashable & Codable & Sendable>(for tab: Tab) -> NavigationTransaction {
        guard let tabs = target as? TabRouter<Tab> else {
            return NavigationTransaction(store: store, missing: notTabsDraft(tab))
        }
        guard let stack = tabs.currentRouter(for: tab) else {
            return NavigationTransaction(store: store, missing: tabs.draft(.unknownTab(DescriptionFormat.name(of: tab))))
        }
        return NavigationTransaction(store: store, target: stack)
    }

    /// Runs a step on the router, with its fallback if it fails, unless an earlier step failed.
    private func onRouter(
        _ context: FallbackContext,
        _ step: (any PresentingRouter) -> StepResult
    ) -> NavigationOutcome {
        if let failure = store.failure {
            return .failed(failure)
        }
        guard let target else {
            return noteMissingTarget(context)
        }
        return store.note(store.resolve(step(target), on: target, context))
    }

    /// Fails a step on a value that names no router.
    private func noteMissingTarget(_ context: FallbackContext) -> NavigationOutcome {
        let issue = missingDraft().issue(file: context.file, line: context.line)
        store.keep(issue)
        return store.note(.failed(NavigationFailure(issue: issue)))
    }

    /// Runs a step that needs a stack.
    private func onStack(_ context: FallbackContext, _ step: (StackRouter) -> StepResult) -> NavigationOutcome {
        onRouter(context) { router in
            guard let stack = router as? StackRouter else {
                return .failed(notStackDraft(router))
            }
            return step(stack)
        }
    }

    /// Runs a step that needs a tab container of `Tab`.
    private func onTabs<Tab: Hashable & Codable & Sendable>(
        of type: Tab.Type,
        _ context: FallbackContext,
        _ step: (TabRouter<Tab>) -> StepResult
    ) -> NavigationOutcome {
        onRouter(context) { router in
            guard let tabs = router as? TabRouter<Tab> else {
                return .failed(notTabsDraft(nil as Tab?))
            }
            return step(tabs)
        }
    }

    /// The fallback context of one step.
    private func context(
        _ fallback: NavigationFallback?,
        _ file: StaticString,
        _ line: UInt,
        route: AnyRoute? = nil
    ) -> FallbackContext {
        FallbackContext(explicit: fallback, route: route, file: file, line: line)
    }

    /// The issue for a step on a value that names no router.
    private func missingDraft() -> IssueDraft {
        missingTarget ?? IssueDraft(kind: .noRouterInScope, flow: FlowID("unknown"), message: "This transaction names no router.")
    }

    /// The issue for a stack step on a container.
    private func notStackDraft(_ router: any PresentingRouter) -> IssueDraft {
        let message = "\(router.flowID) is not a stack. Use router(for:) to navigate one tab's stack."
        return IssueDraft(kind: .flowMismatch, flow: router.flowID, message: message)
    }

    /// The issue for a tab step on a router that isn't a tab container of that tab type.
    private func notTabsDraft<Tab>(_ tab: Tab?) -> IssueDraft {
        let flow = target?.flowID ?? FlowID("unknown")
        let message = "\(flow) is not a tab container of \(Tab.self), so it has no tabs to select."
        return IssueDraft(kind: .unknownTab, flow: flow, message: message)
    }
}
