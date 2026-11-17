//
//  StackRouterTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Testing
import WaypointTestSupport

@testable import WaypointCore

/// `StackRouter`: stack calls, their outcomes and the issues they report (#46).
@Suite("Stack router")
@MainActor
struct StackRouterTests {
    @Test
    func pushAppendsRoute() {
        let router = StackRouter()

        let outcome = router.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
        #expect(router.state.path == [AnyRoute(ProductRoute(id: 1))])
    }

    @Test
    func popRemovesLast() {
        let router = StackRouter()
        router.push(HomeRoute())
        router.push(ProductRoute(id: 1))

        #expect(router.pop() == .applied)
        #expect(router.state.path == [AnyRoute(HomeRoute())])
    }

    @Test
    func popOnEmptyPathFailsWithIssue() throws {
        let router = StackRouter(flow: FlowID("shop"))

        let line: UInt = #line + 1
        let outcome = router.pop()

        let issue = try #require(outcome.failure?.issue)
        #expect(issue.kind == .emptyPath)
        #expect(issue.flow == FlowID("shop"))
        #expect("\(issue.file)" == #fileID)
        #expect(issue.line == line)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func popTooManyFailsWithNotEnoughRoutes() {
        let router = StackRouter()
        router.push(HomeRoute())

        #expect(router.pop(count: 3).failure?.issue.kind == .notEnoughRoutes)
        #expect(router.state.path == [AnyRoute(HomeRoute())])
    }

    @Test
    func popToMissingRouteFailsWithIssue() {
        let router = StackRouter()
        router.push(ProductRoute(id: 1))

        let outcome = router.popTo(SettingsRoute())

        #expect(outcome.failure?.issue.kind == .routeNotInPath)
        #expect(outcome.failure?.fallbackIssue == nil)
        #expect(router.state.path == [AnyRoute(ProductRoute(id: 1))])
    }

    @Test
    func popToTopRouteIsAlreadyThere() {
        let router = StackRouter()
        router.push(ProductRoute(id: 1))

        #expect(router.popTo(ProductRoute(id: 1)) == .alreadyThere)
    }

    @Test
    func popToRootScreenPopsToRoot() {
        let router = StackRouter(root: HomeRoute())
        router.push(ProductRoute(id: 1))
        router.push(ProductRoute(id: 2))

        #expect(router.popTo(HomeRoute()) == .applied)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func popToRootEmptiesPath() {
        let router = StackRouter()
        router.push(ProductRoute(id: 1))

        #expect(router.popToRoot() == .applied)
        #expect(router.popToRoot() == .alreadyThere)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func unregisteredRouteFailsOnceDestinationsAreRegistered() {
        let router = StackRouter()
        router.register(HomeRoute.self)

        let outcome = router.push(ProductRoute(id: 1))

        #expect(outcome.failure?.issue.kind == .unregisteredRoute)
        #expect(router.push(HomeRoute()) == .applied)
        #expect(router.state.path == [AnyRoute(HomeRoute())])
    }

    @Test
    func routesAreNotCheckedBeforeAnyRegistration() {
        let router = StackRouter()

        #expect(router.push(ProductRoute(id: 1)) == .applied)
    }

    @Test
    func registeringFillsTheTreeRegistry() {
        let router = StackRouter()
        router.register(ProductRoute.self)
        router.register(SettingsRoute.self)

        #expect(router.present(SettingsRoute()) == .applied)
        #expect(router.presented?.present(HomeRoute()).failure?.issue.kind == .unregisteredRoute)

        #expect(router.registry.isRegistered(ProductRoute.self))
        #expect(router.presented?.registry.isRegistered(ProductRoute.self) == true)
    }

    @Test
    func observationFiresOncePerCall() {
        let router = StackRouter()
        let fired = FireCounter()
        withObservationTracking {
            _ = router.state
        } onChange: {
            fired.increment()
        }

        router.push(ProductRoute(id: 1))

        #expect(fired.calls == 1)
    }

    @Test
    func failedCallDoesNotTouchState() {
        let router = StackRouter()
        let fired = FireCounter()
        withObservationTracking {
            _ = router.state
        } onChange: {
            fired.increment()
        }

        router.pop()

        #expect(fired.calls == 0)
    }

    @Test
    func rootRouterHasNoParent() {
        let router = StackRouter(flow: FlowID("main"))

        #expect(router.parent == nil)
        #expect(router.root === router)
        #expect(router.flowID == FlowID("main"))
        #expect(router.children.isEmpty)
    }
}
