//
//  PushedChildFlowTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// Pushing a child coordinator's flow: its screens follow on the parent's stack after a marker,
/// its router is a child in the tree, and the parent gets the flow's result exactly once.
@Suite("Pushing child flows")
@MainActor
struct PushedChildFlowTests {
    /// The order number the checkout flow finishes with.
    private static let order = "A-1"

    @Test("Pushing a child flow nests its router on the parent's stack")
    func pushingChildFlowNestsRouter() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()

        let outcome = parent.push(child) { _ in }

        #expect(outcome == .applied)
        #expect(parent.pushedFlow === child.router)
        #expect(parent.children.contains { $0 === child.router })
        #expect(child.router.parent === parent)
        #expect(child.router.isActive)
        #expect(child.router.flowID == FlowID("checkoutFlow"))
        let marker = AnyRoute(ChildFlowRoute(flow: "checkoutFlow", pushID: 1))
        let parentPath = [marker]
        #expect(parent.state.path == parentPath)
        #expect(parent.state.presentation == nil)

        child.router.push(ProductRoute(id: 7))

        let childPath = [AnyRoute(ProductRoute(id: 7))]
        #expect(child.router.state.path == childPath)
        #expect(parent.state.path == parentPath)
    }

    @Test("A pushed flow is cancelled and released when popped")
    func pushedFlowReleasedOnPop() {
        let parent = StackRouter()
        let results = Spy<FlowResult<String>, Void>()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakRouter: StackRouter?
        do {
            let child = CheckoutFlowCoordinator()
            weakChild = child
            weakRouter = child.router
            parent.push(child) { result in
                results(result)
            }
            child.router.push(ProductRoute(id: 7))
        }

        parent.pop()
        RouterTable.shared.sweep()

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
        #expect(parent.state.path.isEmpty)
        #expect(parent.pushedFlow == nil)
        #expect(weakChild == nil)
        #expect(weakRouter == nil)
    }

    @Test("Finishing a pushed child pops to below its root screen")
    func finishPopsBelowTheChildsRootScreen() {
        let parent = StackRouter()
        parent.register(SettingsRoute.self)
        parent.push(SettingsRoute())
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.push(child) { result in
            results(result)
        }
        child.router.push(ProductRoute(id: 7))

        child.finish(with: Self.order)

        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.calls == expected)
        let path = [AnyRoute(SettingsRoute())]
        #expect(parent.state.path == path)
        #expect(!child.router.isActive)
    }

    @Test("dismissFlow from a pushed child pops it and delivers cancelled")
    func dismissFlowFromPushedChildPopsIt() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.push(child) { result in
            results(result)
        }

        let outcome = child.router.dismissFlow()

        #expect(outcome == .applied)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
        #expect(parent.state.path.isEmpty)
    }

    @Test("The user going back past the child's root cancels it")
    func userBackPastTheChildsRootCancels() {
        let parent = StackRouter()
        let results = Spy<FlowResult<String>, Void>()
        parent.push(CheckoutFlowCoordinator()) { result in
            results(result)
        }

        parent.rendererDidPop(toCount: 0)

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
        #expect(parent.pushedFlow == nil)
    }

    @Test("A parent push ends the child on top")
    func parentPushEndsTheChildOnTop() {
        let parent = StackRouter()
        parent.register(SettingsRoute.self)
        let results = Spy<FlowResult<String>, Void>()
        parent.push(CheckoutFlowCoordinator()) { result in
            results(result)
        }

        let outcome = parent.push(SettingsRoute())

        #expect(outcome == .applied)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
        let path = [AnyRoute(SettingsRoute())]
        #expect(parent.state.path == path)
        #expect(parent.pushedFlow == nil)
    }

    @Test("A second pushed child cancels the first")
    func secondPushedChildEndsTheFirst() {
        let parent = StackRouter()
        let first = Spy<FlowResult<String>, Void>()
        let second = Spy<FlowResult<String>, Void>()
        parent.push(CheckoutFlowCoordinator()) { result in
            first(result)
        }
        let child = CheckoutFlowCoordinator()

        parent.push(child) { result in
            second(result)
        }

        let cancelled: [FlowResult<String>] = [.cancelled]
        #expect(first.calls == cancelled)
        #expect(second.calls.isEmpty)
        #expect(parent.pushedFlow === child.router)
        #expect(parent.state.path.count == 1)
    }

    @Test("A parent pop cancels nested pushed children")
    func parentPopCancelsNestedPushedChildren() {
        let parent = StackRouter()
        let outer = Spy<FlowResult<String>, Void>()
        let inner = Spy<FlowResult<String>, Void>()
        let child = CheckoutFlowCoordinator()
        parent.push(child) { result in
            outer(result)
        }
        let grandchild = CheckoutFlowCoordinator()
        child.router.push(grandchild) { result in
            inner(result)
        }

        parent.pop()

        let cancelled: [FlowResult<String>] = [.cancelled]
        #expect(outer.calls == cancelled)
        #expect(inner.calls == cancelled)
        #expect(!grandchild.router.isActive)
    }

    @Test("A pushed child holding the caller's router is refused")
    func pushedChildWithCallersRouterIsRefused() {
        let parent = StackRouter()
        let results = Spy<FlowResult<Int>, Void>()

        let outcome = parent.push(GivenRouterFlowCoordinator(given: parent)) { result in
            results(result)
        }

        #expect(outcome.failure?.issue.kind == .childRouterIsAncestor)
        #expect(parent.state.path.isEmpty)
        #expect(results.calls.isEmpty)
    }

    @Test("A flow's role decides whether it is pushed or presented")
    func flowRoleDecidesHowItIsBuilt() {
        let pushing = StackRouter()
        let presenting = StackRouter()
        let pushed = CheckoutFlowCoordinator()
        let presented = CheckoutFlowCoordinator()

        pushing.push(pushed) { _ in }
        presenting.present(presented) { _ in }

        let marker = AnyRoute(ChildFlowRoute(flow: pushed.router.flowID.name, pushID: 1))
        let pushedPath = [marker]
        #expect(pushing.state.path == pushedPath)
        #expect(pushing.presented == nil)
        #expect(pushing.pushedFlow === pushed.router)
        #expect(presenting.state.path.isEmpty)
        #expect(presenting.presented === presented.router)
        #expect(presenting.pushedFlow == nil)
    }

    @Test("A double tap pushes the flow once")
    func doubleTapPushesTheFlowOnce() {
        let parent = StackRouter()
        let first = Spy<FlowResult<String>, Void>()
        let built = Spy<CheckoutFlowCoordinator, Void>()
        let child = CheckoutFlowCoordinator()
        parent.push(child) { result in
            first(result)
        }
        let marker = parent.state.path.last
        if let marker {
            parent.rendererDidStartPush(of: marker)
        }

        let outcome = parent.push(onFinish: { _ in }) {
            let twin = CheckoutFlowCoordinator()
            built(twin)
            return twin
        }

        #expect(outcome == .alreadyThere)
        #expect(built.calls.isEmpty)
        #expect(first.calls.isEmpty)
        #expect(parent.pushedFlow === child.router)
    }

    @Test("An ignored push builds nothing and never calls onFinish")
    func ignoredPushBuildsNothing() {
        let inert = StackRouter.inert()
        let built = Spy<CheckoutFlowCoordinator, Void>()
        let results = Spy<FlowResult<String>, Void>()

        let outcome = inert.push(onFinish: { result in
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

    @Test("A rolled back push leaves the child as it was, and a retry works")
    func rolledBackPushLeavesChildAsItWas() {
        let parent = StackRouter()
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
            _ = parent.pushChildStep(file: #fileID, line: #line, in: store, onFinish: onFinish) {
                child
            }
            return store.resolve(.failed(draft), on: parent, context)
        }

        #expect(outcome.failure?.issue.kind == .denied)
        #expect(parent.pushedFlow == nil)
        #expect(parent.state.path.isEmpty)
        #expect(child.router.parent == nil)
        #expect(child.router.tree === childTree)
        #expect(child.router.isActive)
        let path = [AnyRoute(ProductRoute(id: 3))]
        #expect(child.router.state.path == path)
        let retried = parent.push(child) { result in
            results(result)
        }
        #expect(retried == .applied)
        #expect(results.calls.isEmpty)
    }
}
