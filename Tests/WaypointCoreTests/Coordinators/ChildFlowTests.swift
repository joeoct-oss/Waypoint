//
//  ChildFlowTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// Presenting a child coordinator's flow: its router joins the parent's tree, and the parent gets
/// the flow's result exactly once (planning #313).
@Suite("Presenting child flows")
@MainActor
struct ChildFlowTests {
    /// The order number the checkout flow finishes with.
    private static let order = "A-1"

    @Test
    func presentingChildCreatesChildRouter() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()

        let outcome = parent.present(child, style: .fullScreenCover) { _ in }

        #expect(outcome == .applied)
        #expect(parent.presented === child.router)
        #expect(child.router.parent === parent)
        #expect(child.router.isActive)
        #expect(child.router.flowID == FlowID("checkoutFlow"))
        #expect(parent.state.presentation?.style == .fullScreenCover)
        #expect(parent.state.presentation?.route == nil)
        #expect(child.router.coordinatorName == "CheckoutFlowCoordinator")
    }

    @Test
    func childKeepsScreensPushedBeforeStart() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        child.router.push(ProductRoute(id: 7))

        parent.present(child) { _ in }

        let path = [AnyRoute(ProductRoute(id: 7))]
        #expect(child.router.state.path == path)
        #expect(parent.registry.isRegistered(ProductRoute.self))
        #expect(child.router.push(ProductRoute(id: 8)) == .applied)
    }

    @Test
    func finishDeliversValueToParent() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }

        child.finish(with: Self.order)

        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.calls == expected)
        #expect(parent.presented == nil)
        #expect(!child.router.isActive)
    }

    @Test
    func userDismissDeliversCancelled() {
        let parent = StackRouter()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(CheckoutFlowCoordinator()) { result in
            results(result)
        }

        parent.rendererDidDismiss()

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func dismissFlowFromChild() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }

        let outcome = child.router.dismissFlow()

        #expect(outcome == .applied)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func replacedPresentationDeliversCancelled() {
        let parent = StackRouter(configuration: .permissive)
        let results = Spy<FlowResult<String>, Void>()
        parent.present(CheckoutFlowCoordinator()) { result in
            results(result)
        }

        let outcome = parent.present(SettingsRoute(), else: .replacePresentation)

        #expect(outcome.recoveredIssue != nil)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func resultDeliveredExactlyOnce() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }

        child.finish(with: Self.order)
        child.finish(with: "B-2")
        parent.dismiss()
        child.router.dismissFlow()

        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.calls == expected)
    }

    @Test
    func dismissWhileFinishingDeliversOnce() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }
        parent.tree.onApplied { _ in
            child.finish(with: Self.order)
        }

        parent.rendererDidDismiss()

        #expect(results.callCount == 1)
    }

    @Test
    func finishWhileTheDismissIsQueuedDeliversTheValue() {
        let parent = StackRouter(configuration: .permissive)
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }
        parent.tree.onApplied { _ in
            child.finish(with: Self.order)
        }

        child.router.push(ProductRoute(id: 1))

        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.calls == expected)
    }

    @Test
    func resultArrivesAfterTheCallThatEndedTheFlow() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let presentedWhenDelivered = Spy<Bool, Void>()
        parent.present(child) { _ in
            presentedWhenDelivered(parent.presented != nil)
        }

        parent.dismiss()

        let expected = [false]
        #expect(presentedWhenDelivered.calls == expected)
    }

    @Test
    func parentDismissCancelsNestedChildren() {
        let parent = StackRouter()
        let outer = CheckoutFlowCoordinator()
        let results = Spy<String, Void>()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakInner: CheckoutFlowCoordinator?
        parent.present(outer) { result in
            results("outer \(result)")
        }
        do {
            let inner = CheckoutFlowCoordinator()
            weakInner = inner
            outer.router.present(inner) { result in
                results("inner \(result)")
            }
        }

        parent.dismiss()

        let expected = ["outer cancelled", "inner cancelled"]
        #expect(results.calls.sorted() == expected.sorted())
        #expect(weakInner == nil)
    }

    @Test
    func sweptParentCancelsItsChildren() {
        let results = Spy<FlowResult<String>, Void>()
        do {
            let owner = ShopListCoordinator()
            owner.router.present(CheckoutFlowCoordinator()) { result in
                results(result)
            }
        }

        RouterTable.shared.sweep()

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func childReleasedAfterFinish() {
        let parent = StackRouter()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        weak var weakRouter: StackRouter?
        do {
            let child = CheckoutFlowCoordinator()
            weakChild = child
            weakRouter = child.router
            parent.present(child) { _ in }
        }
        #expect(weakChild != nil)

        weakChild?.finish(with: Self.order)
        RouterTable.shared.sweep()

        #expect(weakChild == nil)
        #expect(weakRouter == nil)
    }

    @Test
    func droppedParentReleasesAndCancelsItsChild() {
        let results = Spy<FlowResult<String>, Void>()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        weak var weakRouter: StackRouter?
        do {
            let parent = StackRouter()
            let child = CheckoutFlowCoordinator()
            weakChild = child
            weakRouter = child.router
            parent.present(child) { result in
                results(result)
            }
        }

        RouterTable.shared.sweep()

        #expect(weakChild == nil)
        #expect(weakRouter == nil)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func presentedFlowReleasedOnDismiss() {
        let parent = StackRouter()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        weak var weakRouter: StackRouter?
        do {
            let child = CheckoutFlowCoordinator()
            weakChild = child
            weakRouter = child.router
            parent.present(child) { _ in }
        }

        parent.rendererDidDismiss()
        RouterTable.shared.sweep()

        #expect(weakChild == nil)
        #expect(weakRouter == nil)
    }

    @Test
    func finishReleasesRouterAndCoordinator() {
        let parent = StackRouter()
        let results = Spy<FlowResult<String>, Void>()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        do {
            let child = CheckoutFlowCoordinator()
            weakChild = child
            parent.present(child) { result in
                results(result)
            }
            child.finish(with: Self.order)
        }

        RouterTable.shared.sweep()

        #expect(weakChild == nil)
        #expect(results.callCount == 1)
    }

    @Test(arguments: Self.refusingRouters)
    func childWithCallersRouterIsRefused(refusing: RefusingRouter) {
        let root = StackRouter()
        if refusing == .ancestor {
            root.present(CheckoutFlowCoordinator()) { _ in }
        }
        let presenter = root.presented ?? root
        let child = GivenRouterFlowCoordinator(given: root)
        let results = Spy<FlowResult<Int>, Void>()

        let outcome = presenter.present(child) { result in
            results(result)
        }

        #expect(outcome.failure?.issue.kind == .childRouterIsAncestor)
        #expect(results.calls.isEmpty)
    }

    @Test
    func childFromAnotherTreeIsRefused() throws {
        let first = StackRouter()
        let second = StackRouter()
        let child = CheckoutFlowCoordinator()
        first.present(child) { _ in }
        let results = Spy<FlowResult<String>, Void>()

        let outcome = second.present(child) { result in
            results(result)
        }

        let issue = try #require(outcome.failure?.issue)
        #expect(issue.kind == .routerInAnotherTree)
        #expect(issue.message.contains("CheckoutFlowCoordinator"))
        #expect(child.router.parent === first)
        #expect(results.calls.isEmpty)
    }

    @Test
    func refusedPresentNeverCallsOnFinish() {
        let parent = StackRouter(configuration: .permissive)
        parent.present(SettingsRoute())
        let results = Spy<FlowResult<String>, Void>()
        let built = Spy<CheckoutFlowCoordinator, Void>()

        let outcome = parent.present(onFinish: { result in
            results(result)
        }) {
            let child = CheckoutFlowCoordinator()
            built(child)
            return child
        }
        parent.dismiss()

        #expect(outcome.failure?.issue.kind == .alreadyPresenting)
        #expect(built.calls.isEmpty)
        #expect(results.calls.isEmpty)
    }

    @Test
    func recoveredPresentDeliversOnce() {
        let parent = StackRouter(configuration: .permissive)
        parent.present(SettingsRoute())
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()

        let outcome = parent.present(child, else: .replacePresentation) { result in
            results(result)
        }
        child.finish(with: Self.order)

        #expect(outcome.recoveredIssue != nil)
        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.calls == expected)
    }

    @Test
    func ignoredPresentBuildsNothing() {
        let inert = StackRouter.inert()
        let built = Spy<CheckoutFlowCoordinator, Void>()
        let results = Spy<FlowResult<String>, Void>()

        let outcome = inert.present(onFinish: { result in
            results(result)
        }) {
            let child = CheckoutFlowCoordinator()
            built(child)
            return child
        }

        #expect(outcome == .ignored)
        #expect(built.calls.isEmpty)
        #expect(results.calls.isEmpty)
    }

    @Test
    func queuedPresentThatFailsNeverCallsOnFinish() {
        let parent = StackRouter(configuration: .permissive)
        let built = Spy<CheckoutFlowCoordinator, Void>()
        let results = Spy<FlowResult<String>, Void>()
        let outcomes = Spy<NavigationOutcome, Void>()
        parent.tree.onApplied { _ in
            guard outcomes.calls.isEmpty else {
                return
            }
            let outcome = parent.present(onFinish: { result in
                results(result)
            }) {
                let child = CheckoutFlowCoordinator()
                built(child)
                return child
            }
            outcomes(outcome)
        }

        parent.present(SettingsRoute())
        parent.dismiss()

        let expected: [NavigationOutcome] = [.queued]
        #expect(outcomes.calls == expected)
        #expect(built.calls.isEmpty)
        #expect(results.calls.isEmpty)
    }

    @Test
    func queuedPresentBuildsTheChildWhenItRuns() {
        let parent = StackRouter(configuration: .permissive)
        let built = Spy<CheckoutFlowCoordinator, Void>()
        let builtWhenQueued = Spy<Int, Void>()
        parent.tree.onApplied { _ in
            guard parent.presented == nil, built.calls.isEmpty else {
                return
            }
            parent.present(onFinish: { _ in }) {
                let child = CheckoutFlowCoordinator()
                built(child)
                return child
            }
            builtWhenQueued(built.callCount)
        }

        parent.push(ProductRoute(id: 1))

        let expected = [0]
        #expect(builtWhenQueued.calls == expected)
        #expect(parent.presented === built.lastCall?.router)
    }

    @Test
    func lazyChildPushInInitUsesRootSettings() throws {
        let parent = StackRouter(configuration: .permissive)
        let lazyChild = Spy<PushingInInitFlowCoordinator, Void>()

        parent.present(onFinish: { _ in }) {
            let child = PushingInInitFlowCoordinator()
            lazyChild(child)
            return child
        }
        let eagerChild = PushingInInitFlowCoordinator()

        let child = try #require(lazyChild.lastCall)
        let path = [AnyRoute(ProductRoute(id: 1))]
        #expect(child.router.state.path == path)
        #expect(child.router.parent === parent)
        #expect(eagerChild.outcomes.lastCall?.failure?.issue.kind == .unregisteredRoute)
    }

    @Test
    func extraRouterInLazyClosureStaysSeparate() throws {
        let parent = StackRouter()
        let made = Spy<InnerMakingFlowCoordinator, Void>()

        parent.present(onFinish: { _ in }) {
            let child = InnerMakingFlowCoordinator()
            made(child)
            return child
        }

        let child = try #require(made.lastCall)
        #expect(child.router.parent === parent)
        #expect(child.inner.router.tree !== parent.tree)
        #expect(child.inner.router.parent == nil)
    }

    @Test
    func markedRouterOfAGrandchildIsDetached() throws {
        let parent = StackRouter()
        let reported = Spy<NavigationIssue, Void>()
        parent.tree.onReported { issue in
            reported(issue)
        }
        let made = Spy<TwinMakingFlowCoordinator, Void>()

        let outcome = parent.present(onFinish: { _ in }) {
            let child = TwinMakingFlowCoordinator(makingTwin: true)
            made(child)
            return child
        }

        let child = try #require(made.lastCall)
        let twin = try #require(child.twin)
        #expect(outcome == .applied)
        #expect(child.router.parent === parent)
        #expect(twin.router.tree !== parent.tree)
        #expect(twin.router.parent == nil)
        let kinds = reported.calls.map(\.kind)
        let expected: [NavigationIssue.Kind] = [.routerDetachedFromLazyStart]
        #expect(kinds == expected)
    }

    @Test
    func lazyChildOwnMakeRouterJoinsOnStart() throws {
        let parent = StackRouter()
        let made = Spy<OwnRouterFlowCoordinator, Void>()

        parent.present(onFinish: { _ in }) {
            let child = OwnRouterFlowCoordinator()
            made(child)
            return child
        }

        let child = try #require(made.lastCall)
        #expect(child.outcomes.lastCall == .applied)
        let path = [AnyRoute(ProductRoute(id: 1))]
        #expect(child.router.state.path == path)
        #expect(child.router.parent === parent)
    }

    @Test
    func lazyChildRouterFromAnotherTreeIsRefused() {
        let other = StackRouter()
        other.present(CheckoutFlowCoordinator()) { _ in }
        let parent = StackRouter()
        let results = Spy<FlowResult<Int>, Void>()

        let outcome = parent.present(onFinish: { result in
            results(result)
        }) {
            GivenRouterFlowCoordinator(given: other.presented ?? other)
        }

        #expect(outcome.failure?.issue.kind == .routerInAnotherTree)
        #expect(parent.presented == nil)
        #expect(results.calls.isEmpty)
    }

    @Test
    func twoLazyStartsInOneTurnJoinTheirOwnParents() throws {
        let first = StackRouter()
        let second = StackRouter()
        let made = Spy<StartingFlowCoordinator, Void>()

        first.present(onFinish: { _ in }) {
            let child = StartingFlowCoordinator(startingOn: second)
            made(child)
            return child
        }

        let child = try #require(made.lastCall)
        let grandchild = try #require(child.started.lastCall)
        #expect(child.router.parent === first)
        #expect(grandchild.router.parent === second)
        #expect(first.presented === child.router)
        #expect(second.presented === grandchild.router)
    }

    @Test
    func dyingCoordinatorInLazyClosureNeverTakesTheMark() throws {
        let parent = StackRouter()
        let deinitRouters = Spy<StackRouter, Void>()
        let made = Spy<DyingFlowCoordinator, Void>()

        parent.present(onFinish: { _ in }) {
            _ = DyingFlowCoordinator(deinitRouters: deinitRouters, readingRouter: false)
            let child = DyingFlowCoordinator(deinitRouters: deinitRouters, readingRouter: true)
            made(child)
            return child
        }

        let dyingRouter = try #require(deinitRouters.lastCall)
        let child = try #require(made.lastCall)
        #expect(dyingRouter.tree !== parent.tree)
        #expect(!dyingRouter.isActive)
        #expect(child.router.parent === parent)
        #expect(child.router.flowID == FlowID("dyingFlow"))
    }

    @Test(arguments: Self.bothForms)
    func bothFormsDeliverTheSameResults(form: StartForm) {
        let finished = Spy<FlowResult<String>, Void>()
        let cancelled = Spy<FlowResult<String>, Void>()
        let finishing = CheckoutFlowCoordinator()
        let parent = StackRouter()
        let other = StackRouter()

        form.start(finishing, on: parent, into: finished)
        form.start(CheckoutFlowCoordinator(), on: other, into: cancelled)
        finishing.finish(with: Self.order)
        other.rendererDidDismiss()

        let expectedFinished: [FlowResult<String>] = [.finished(Self.order)]
        let expectedCancelled: [FlowResult<String>] = [.cancelled]
        #expect(finished.calls == expectedFinished)
        #expect(cancelled.calls == expectedCancelled)
    }

    @Test
    func presentingChildOverTabsJoinsTheContainer() {
        let tabs = TabRouter(selection: MainTab.home)
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()

        let outcome = tabs.present(child) { result in
            results(result)
        }
        child.finish(with: Self.order)

        #expect(outcome == .applied)
        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.calls == expected)
    }

    @Test
    func tabsKeepTheirChildUntilItFinishes() {
        let tabs = TabRouter(selection: MainTab.home)
        let results = Spy<FlowResult<String>, Void>()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        do {
            let child = CheckoutFlowCoordinator()
            weakChild = child
            tabs.present(child) { result in
                results(result)
            }
        }
        RouterTable.shared.sweep()
        #expect(weakChild != nil)

        weakChild?.finish(with: Self.order)
        RouterTable.shared.sweep()

        #expect(weakChild == nil)
        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.calls == expected)
    }

    @Test
    func userDismissOverTabsDeliversCancelled() {
        let tabs = TabRouter(selection: MainTab.home)
        let results = Spy<FlowResult<String>, Void>()
        tabs.present(CheckoutFlowCoordinator()) { result in
            results(result)
        }

        tabs.rendererDidDismiss()

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func droppedTabsReleaseAndCancelTheirChild() {
        let results = Spy<FlowResult<String>, Void>()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        do {
            let tabs = TabRouter(selection: MainTab.home)
            let child = CheckoutFlowCoordinator()
            weakChild = child
            tabs.present(child) { result in
                results(result)
            }
        }

        RouterTable.shared.sweep()

        #expect(weakChild == nil)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func rolledBackStartOverTabsLeavesChildAsItWas() {
        let tabs = TabRouter(selection: MainTab.home)
        let child = CheckoutFlowCoordinator()
        let childTree = child.router.tree
        let results = Spy<FlowResult<String>, Void>()
        let draft = IssueDraft(kind: .denied, flow: tabs.flowID, message: "Denied after the start.")
        let context = FallbackContext(explicit: nil, file: #fileID, line: #line)
        let onFinish: @MainActor (FlowResult<String>) -> Void = { result in
            results(result)
        }

        let outcome = tabs.tree.perform(on: tabs, file: #fileID, line: #line) { store in
            _ = tabs.presentChildStep(style: .sheet, file: #fileID, line: #line, in: store, onFinish: onFinish) {
                child
            }
            return store.resolve(.failed(draft), on: tabs, context)
        }

        #expect(outcome.failure?.issue.kind == .denied)
        #expect(tabs.presented == nil)
        #expect(child.router.parent == nil)
        #expect(child.router.tree === childTree)
        #expect(child.router.isActive)
        #expect(results.calls.isEmpty)
    }

    @Test
    func finishOutsideAFlowIsReported() {
        let child = CheckoutFlowCoordinator()
        let reported = Spy<NavigationIssue, Void>()
        child.router.tree.onReported { issue in
            reported(issue)
        }

        child.finish(with: Self.order)

        let kinds = reported.calls.map(\.kind)
        let expected: [NavigationIssue.Kind] = [.notPresented]
        #expect(kinds == expected)
    }

    @Test
    func rolledBackStartLeavesChildAsItWas() {
        let parent = StackRouter()
        parent.register(SettingsRoute.self)
        let child = CheckoutFlowCoordinator()
        child.router.push(ProductRoute(id: 3))
        let childTree = child.router.tree
        let results = Spy<FlowResult<String>, Void>()
        let draft = IssueDraft(kind: .denied, flow: parent.flowID, message: "Denied after the start.")

        let context = FallbackContext(explicit: nil, file: #fileID, line: #line)
        let onFinish: @MainActor (FlowResult<String>) -> Void = { result in
            results(result)
        }

        let outcome = parent.tree.perform(on: parent, file: #fileID, line: #line) { store in
            _ = parent.presentChildStep(style: .sheet, file: #fileID, line: #line, in: store, onFinish: onFinish) {
                child
            }
            return store.resolve(.failed(draft), on: parent, context)
        }

        #expect(outcome.failure?.issue.kind == .denied)
        #expect(parent.presented == nil)
        #expect(child.router.parent == nil)
        #expect(child.router.tree === childTree)
        #expect(child.router.flowID == FlowID("main"))
        #expect(!child.router.registry.isRegistered(SettingsRoute.self))
        #expect(child.router.isActive)
        let path = [AnyRoute(ProductRoute(id: 3))]
        #expect(child.router.state.path == path)
        let retried = parent.present(child) { result in
            results(result)
        }
        #expect(retried == .applied)
        #expect(results.calls.isEmpty)
    }
}

/// Which router a refused child's router is.
///
/// Conformances:
/// - `CaseIterable`, so a test runs once for each.
/// - `Sendable`, so Swift Testing can pass it to the test as an argument.
enum RefusingRouter: CaseIterable, Sendable {
    /// The router presenting the child.
    case caller
    /// The root of the tree the presenter is in.
    case ancestor
}

/// The two ways to start a child flow.
///
/// Conformances:
/// - `CaseIterable`, so a test runs once for each.
/// - `Sendable`, so Swift Testing can pass it to the test as an argument.
enum StartForm: CaseIterable, Sendable {
    /// Passing the child.
    case eager
    /// Passing a closure that builds it.
    case lazy

    /// Starts `child` on `parent`, recording its result in `results`.
    @MainActor
    func start(_ child: CheckoutFlowCoordinator, on parent: StackRouter, into results: Spy<FlowResult<String>, Void>) {
        switch self {
        case .eager:
            parent.present(child) { result in
                results(result)
            }
        case .lazy:
            parent.present(onFinish: { result in
                results(result)
            }) {
                child
            }
        }
    }
}

extension ChildFlowTests {
    /// Every refusing router.
    nonisolated static let refusingRouters = RefusingRouter.allCases

    /// Both start forms.
    nonisolated static let bothForms = StartForm.allCases
}
