//
//  PushedChildFlowTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Pushing a child coordinator's flow: its screens follow on the parent's stack after a marker,
/// its router is a child in the tree, and the parent gets the flow's result exactly once (#59).
@Suite("Pushing child flows")
@MainActor
struct PushedChildFlowTests {
    /// The order number the checkout flow finishes with.
    private static let order = "A-1"

    @Test
    func pushingChildFlowNestsRouter() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()

        let outcome = parent.push(child) { _ in }

        #expect(outcome == .applied)
        #expect(parent.pushed === child.router)
        #expect(parent.children.contains { $0 === child.router })
        #expect(child.router.parent === parent)
        #expect(child.router.isActive)
        #expect(child.router.flowID == FlowID("checkoutFlow"))
        let marker = AnyRoute(ChildFlowRoute(flow: "checkoutFlow"))
        let parentPath = [marker]
        #expect(parent.state.path == parentPath)
        #expect(parent.state.presentation == nil)

        child.router.push(ProductRoute(id: 7))

        let childPath = [AnyRoute(ProductRoute(id: 7))]
        #expect(child.router.state.path == childPath)
        #expect(parent.state.path == parentPath)
    }

    @Test
    func pushedFlowReleasedOnPop() {
        let parent = StackRouter()
        let results = Recorder<FlowResult<String>>()
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        // `var` because a weak reference must be one: it reads `nil` once the test lets go.
        weak var weakRouter: StackRouter?
        do {
            let child = CheckoutFlowCoordinator()
            weakChild = child
            weakRouter = child.router
            parent.push(child) { result in
                results.record(result)
            }
            child.router.push(ProductRoute(id: 7))
        }

        parent.pop()
        RouterTable.shared.sweep()

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.values == expected)
        #expect(parent.state.path.isEmpty)
        #expect(parent.pushed == nil)
        #expect(weakChild == nil)
        #expect(weakRouter == nil)
    }

    @Test
    func finishPopsBelowTheChildsRootScreen() {
        let parent = StackRouter()
        parent.register(SettingsRoute.self)
        parent.push(SettingsRoute())
        let child = CheckoutFlowCoordinator()
        let results = Recorder<FlowResult<String>>()
        parent.push(child) { result in
            results.record(result)
        }
        child.router.push(ProductRoute(id: 7))

        child.finish(with: Self.order)

        let expected: [FlowResult<String>] = [.finished(Self.order)]
        #expect(results.values == expected)
        let path = [AnyRoute(SettingsRoute())]
        #expect(parent.state.path == path)
        #expect(!child.router.isActive)
    }

    @Test
    func dismissFlowFromPushedChildPopsIt() {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let results = Recorder<FlowResult<String>>()
        parent.push(child) { result in
            results.record(result)
        }

        let outcome = child.router.dismissFlow()

        #expect(outcome == .applied)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.values == expected)
        #expect(parent.state.path.isEmpty)
    }

    @Test
    func userBackPastTheChildsRootCancels() {
        let parent = StackRouter()
        let results = Recorder<FlowResult<String>>()
        parent.push(CheckoutFlowCoordinator()) { result in
            results.record(result)
        }

        parent.rendererDidPop(toCount: 0)

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.values == expected)
        #expect(parent.pushed == nil)
    }

    @Test
    func parentPushEndsTheChildOnTop() {
        let parent = StackRouter()
        parent.register(SettingsRoute.self)
        let results = Recorder<FlowResult<String>>()
        parent.push(CheckoutFlowCoordinator()) { result in
            results.record(result)
        }

        let outcome = parent.push(SettingsRoute())

        #expect(outcome == .applied)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.values == expected)
        let path = [AnyRoute(SettingsRoute())]
        #expect(parent.state.path == path)
        #expect(parent.pushed == nil)
    }

    @Test
    func secondPushedChildEndsTheFirst() {
        let parent = StackRouter()
        let first = Recorder<FlowResult<String>>()
        let second = Recorder<FlowResult<String>>()
        parent.push(CheckoutFlowCoordinator()) { result in
            first.record(result)
        }
        let child = CheckoutFlowCoordinator()

        parent.push(child) { result in
            second.record(result)
        }

        let cancelled: [FlowResult<String>] = [.cancelled]
        #expect(first.values == cancelled)
        #expect(second.values.isEmpty)
        #expect(parent.pushed === child.router)
        #expect(parent.state.path.count == 1)
    }

    @Test
    func parentPopCancelsNestedPushedChildren() {
        let parent = StackRouter()
        let outer = Recorder<FlowResult<String>>()
        let inner = Recorder<FlowResult<String>>()
        let child = CheckoutFlowCoordinator()
        parent.push(child) { result in
            outer.record(result)
        }
        let grandchild = CheckoutFlowCoordinator()
        child.router.push(grandchild) { result in
            inner.record(result)
        }

        parent.pop()

        let cancelled: [FlowResult<String>] = [.cancelled]
        #expect(outer.values == cancelled)
        #expect(inner.values == cancelled)
        #expect(!grandchild.router.isActive)
    }

    @Test
    func pushedChildWithCallersRouterIsRefused() {
        let parent = StackRouter()
        let results = Recorder<FlowResult<Int>>()

        let outcome = parent.push(GivenRouterFlowCoordinator(given: parent)) { result in
            results.record(result)
        }

        #expect(outcome.failure?.issue.kind == .childRouterIsAncestor)
        #expect(parent.state.path.isEmpty)
        #expect(results.values.isEmpty)
    }

    @Test
    func flowRoleDecidesHowItIsBuilt() {
        let pushing = StackRouter()
        let presenting = StackRouter()
        let pushed = CheckoutFlowCoordinator()
        let presented = CheckoutFlowCoordinator()

        pushing.push(pushed) { _ in }
        presenting.present(presented) { _ in }

        let marker = AnyRoute(ChildFlowRoute(flow: pushed.router.flowID.name))
        let pushedPath = [marker]
        #expect(pushing.state.path == pushedPath)
        #expect(pushing.presented == nil)
        #expect(pushing.pushed === pushed.router)
        #expect(presenting.state.path.isEmpty)
        #expect(presenting.presented === presented.router)
        #expect(presenting.pushed == nil)
    }
}
