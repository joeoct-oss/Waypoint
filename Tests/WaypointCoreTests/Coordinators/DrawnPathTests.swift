//
//  DrawnPathTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// What one stack shows when child flows are pushed on it, and which router hears what the user
/// does to each screen (planning #313).
@Suite("Drawn path of pushed child flows")
@MainActor
struct DrawnPathTests {
    @Test
    func drawnPathFollowsTheMarkerWithTheChildsPath() throws {
        let parent = StackRouter(configuration: .permissive)
        parent.push(HomeRoute())
        let child = CheckoutFlowCoordinator()
        parent.push(child) { _ in }
        child.router.push(ProductRoute(id: 7))

        let marker = try #require(child.router.marker)
        let expected = [AnyRoute(HomeRoute()), marker, AnyRoute(ProductRoute(id: 7))]
        #expect(parent.drawnPath == expected)
        let childPath = [AnyRoute(ProductRoute(id: 7))]
        #expect(child.router.drawnPath == childPath)
    }

    @Test
    func eachDrawnScreenBelongsToTheRouterWhosePathHoldsIt() {
        let parent = StackRouter(configuration: .permissive)
        parent.push(HomeRoute())
        let child = CheckoutFlowCoordinator()
        parent.push(child) { _ in }
        child.router.push(ProductRoute(id: 7))

        #expect(parent.drawnOwner(ofIndex: 0) === parent)
        #expect(parent.drawnOwner(ofIndex: 1) === parent)
        #expect(parent.drawnOwner(ofIndex: 2) === child.router)
    }

    @Test
    func aGrandchildsScreensFollowItsParentsOnTheOneStack() throws {
        let parent = StackRouter(configuration: .permissive)
        let child = CheckoutFlowCoordinator()
        parent.push(child) { _ in }
        child.router.push(ProductRoute(id: 7))
        let grandchild = CheckoutFlowCoordinator()
        child.router.push(grandchild) { _ in }
        grandchild.router.push(CartRoute())

        let childMarker = try #require(child.router.marker)
        let grandchildMarker = try #require(grandchild.router.marker)
        let expected = [childMarker, AnyRoute(ProductRoute(id: 7)), grandchildMarker, AnyRoute(CartRoute())]
        #expect(parent.drawnPath == expected)
        #expect(parent.drawnOwner(ofIndex: 3) === grandchild.router)
        #expect(parent.drawnParent(ofMarker: childMarker) === parent)
        #expect(parent.drawnParent(ofMarker: grandchildMarker) === child.router)
        #expect(parent.drawnParent(ofMarker: AnyRoute(CartRoute())) == nil)
    }

    @Test
    func backInsideTheChildPopsTheChildsPath() {
        let parent = StackRouter(configuration: .permissive)
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.push(child) { result in
            results(result)
        }
        child.router.push(ProductRoute(id: 7))
        child.router.push(CartRoute())

        parent.rendererDidPopDrawn(toCount: 2)
        let afterOneBack = child.router.state.path
        parent.rendererDidPopDrawn(toCount: 1)

        let expectedAfterOneBack = [AnyRoute(ProductRoute(id: 7))]
        #expect(afterOneBack == expectedAfterOneBack)
        #expect(child.router.state.path.isEmpty)
        #expect(parent.pushedFlow === child.router)
        #expect(results.calls.isEmpty)
    }

    @Test
    func backPastTheChildsRootEndsItCancelled() {
        let parent = StackRouter(configuration: .permissive)
        parent.push(HomeRoute())
        let child = CheckoutFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.push(child) { result in
            results(result)
        }
        child.router.push(ProductRoute(id: 7))

        parent.rendererDidPopDrawn(toCount: 1)

        let parentPath = [AnyRoute(HomeRoute())]
        #expect(parent.state.path == parentPath)
        #expect(parent.pushedFlow == nil)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    @Test
    func theSameFlowPushedAgainGetsANewMarker() throws {
        let parent = StackRouter(configuration: .permissive)
        let first = CheckoutFlowCoordinator()
        parent.push(first) { _ in }
        let firstMarker = try #require(first.router.marker)
        parent.rendererDidPopDrawn(toCount: 0)

        let second = CheckoutFlowCoordinator()
        parent.push(second) { _ in }

        let secondMarker = try #require(second.router.marker)
        #expect(second.router.flowID == first.router.flowID)
        #expect(secondMarker != firstMarker)
        let expected = [secondMarker]
        #expect(parent.drawnPath == expected)
    }

    @Test
    func drawnCountPastTheEndIsAMismatch() {
        let parent = StackRouter(configuration: .permissive)
        let reported = Spy<NavigationIssue, Void>()
        parent.tree.onReported { issue in
            reported(issue)
        }
        let child = CheckoutFlowCoordinator()
        parent.push(child) { _ in }

        parent.rendererDidPopDrawn(toCount: 3)

        let expectedKinds: [NavigationIssue.Kind] = [.rendererMismatch]
        #expect(reported.calls.map(\.kind) == expectedKinds)
        #expect(parent.drawnPath.count == 1)
    }
}
