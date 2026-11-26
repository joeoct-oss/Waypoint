//
//  StackRouterTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Testing
import WaypointTestSupport

@testable import WaypointCore

/// `StackRouter`: stack calls, their outcomes and the issues they report.
@Suite("Stack router")
@MainActor
struct StackRouterTests {
    @Test("A push appends the route")
    func pushAppendsRoute() {
        let router = StackRouter(configuration: .permissive)

        let outcome = router.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test("A pop removes the last route")
    func popRemovesLast() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())
        router.push(ProductRoute(id: 1))

        #expect(router.pop() == .applied)
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
    }

    @Test("A pop with a count removes that many from the top")
    func popCountRemovesThatManyFromTheTop() {
        let router = StackRouter(configuration: .permissive)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
            ProductRoute(id: 2)
        }

        #expect(router.pop(count: 2) == .applied)
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
    }

    @Test("A pop of zero is already there")
    func popOfZeroIsAlreadyThere() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())

        #expect(router.pop(count: 0) == .alreadyThere)
        #expect(router.state.path.count == 1)
    }

    @Test("A push of no routes is already there")
    func pushOfNoRoutesIsAlreadyThere() {
        let router = StackRouter(configuration: .permissive)
        let none: [ProductRoute] = []

        let outcome = router.push {
            for route in none {
                route
            }
        }

        #expect(outcome == .alreadyThere)
        #expect(router.state.path.isEmpty)
    }

    @Test("A push under a presented flow keeps the flow")
    func pushUnderAPresentedFlowKeepsIt() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let presented = try #require(router.presented)

        #expect(router.push(ProductRoute(id: 1)) == .applied)

        #expect(router.presented === presented)
        #expect(router.state.path.count == 1)
    }

    @Test("A pop on an empty path fails with an issue naming the flow and call site")
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

    @Test("Popping too many recovers by going to the root")
    func popTooManyRecoversToRoot() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())

        let outcome = router.pop(count: 3)

        #expect(outcome.recoveredIssue?.kind == .notEnoughRoutes)
        let counts = "pop(count: 3) asked for 3 routes, but the path holds 1."
        #expect(outcome.recoveredIssue?.message.hasPrefix(counts) == true)
        #expect(outcome.description == "recovered notEnoughRoutes by=popToRoot")
        #expect(router.state.path.isEmpty)
    }

    @Test("popTo a route not in the path fails and leaves the path")
    func popToMissingRouteFailsWithIssue() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        let outcome = router.popTo(SettingsRoute())

        #expect(outcome.failure?.issue.kind == .routeNotInPath)
        #expect(outcome.failure?.fallbackIssue == nil)
        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test("popTo the top route is already there")
    func popToTopRouteIsAlreadyThere() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        #expect(router.popTo(ProductRoute(id: 1)) == .alreadyThere)
    }

    @Test("popTo stops at the last match")
    func popToStopsAtTheLastMatch() {
        let router = StackRouter(configuration: .permissive)
        router.push {
            ProductRoute(id: 1)
            SettingsRoute()
            ProductRoute(id: 1)
            ProductRoute(id: 2)
        }

        #expect(router.popTo(ProductRoute(id: 1)) == .applied)

        let expectedPath = [AnyRoute(ProductRoute(id: 1)), AnyRoute(SettingsRoute()), AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test("popTo the root screen's route pops to the root")
    func popToRootScreenPopsToRoot() {
        let router = StackRouter(root: HomeRoute(), configuration: .permissive)
        router.push(ProductRoute(id: 1))
        router.push(ProductRoute(id: 2))

        #expect(router.popTo(HomeRoute()) == .applied)
        #expect(router.state.path.isEmpty)
    }

    @Test("popToRoot empties the path, and again is already there")
    func popToRootEmptiesPath() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        #expect(router.popToRoot() == .applied)
        #expect(router.popToRoot() == .alreadyThere)
        #expect(router.state.path.isEmpty)
    }

    @Test("An unregistered route fails while registered ones push")
    func unregisteredRouteFailsBesideRegisteredOnes() {
        let router = StackRouter()
        router.register(HomeRoute.self)

        let outcome = router.push(ProductRoute(id: 1))

        #expect(outcome.failure?.issue.kind == .unregisteredRoute)
        #expect(router.push(HomeRoute()) == .applied)
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
    }

    @Test("An empty strict registry refuses pushes and presents")
    func emptyStrictRegistryRejectsPush() {
        let router = StackRouter()

        let outcome = router.push(ProductRoute(id: 1))

        #expect(outcome.failure?.issue.kind == .unregisteredRoute)
        #expect(router.present(SettingsRoute()).failure?.issue.kind == .unregisteredRoute)
        #expect(router.state.path.isEmpty)
        #expect(router.registry.mode == .strict)
    }

    @Test("A permissive registry accepts any route")
    func permissiveRegistryAcceptsAnyRoute() {
        let router = StackRouter(configuration: NavigationConfiguration(registry: .permissive))

        #expect(router.push(ProductRoute(id: 1)) == .applied)
        #expect(router.present(SettingsRoute()) == .applied)
    }

    @Test("Registering routes doesn't change the registry's mode")
    func registeringDoesNotChangeMode() {
        let strict = StackRouter()
        let permissive = StackRouter(configuration: NavigationConfiguration(registry: .permissive))

        strict.register(HomeRoute.self)
        permissive.register(HomeRoute.self)

        #expect(strict.registry.mode == .strict)
        #expect(strict.push(ProductRoute(id: 1)).failure?.issue.kind == .unregisteredRoute)
        #expect(permissive.registry.mode == .permissive)
        #expect(permissive.push(ProductRoute(id: 1)) == .applied)
        #expect(permissive.registry.isRegistered(HomeRoute.self))
    }

    @Test("An unregistered route runs its fallback")
    func unregisteredRouteRunsItsFallback() {
        let router = StackRouter()
        router.register(HomeRoute.self)
        router.push(HomeRoute())

        let outcome = router.push(ProductRoute(id: 1), else: .popToRoot)

        #expect(outcome.recoveredIssue?.kind == .unregisteredRoute)
        #expect(router.state.path.isEmpty)
    }

    @Test("Registering fills the registry the whole tree shares")
    func registeringFillsTheTreeRegistry() {
        let router = StackRouter()
        router.register(ProductRoute.self)
        router.register(SettingsRoute.self)

        #expect(router.present(SettingsRoute()) == .applied)
        #expect(router.presented?.present(HomeRoute()).failure?.issue.kind == .unregisteredRoute)

        #expect(router.registry.isRegistered(ProductRoute.self))
        #expect(router.presented?.registry.isRegistered(ProductRoute.self) == true)
    }

    @Test("Observation fires once per call")
    func observationFiresOncePerCall() {
        let router = StackRouter(configuration: .permissive)
        let fired = FireCounter()
        withObservationTracking {
            _ = router.state
        } onChange: {
            fired.increment()
        }

        router.push(ProductRoute(id: 1))

        #expect(fired.calls == 1)
    }

    @Test("A failed call doesn't touch observed state")
    func failedCallDoesNotTouchState() {
        let router = StackRouter(configuration: .permissive)
        let fired = FireCounter()
        withObservationTracking {
            _ = router.state
        } onChange: {
            fired.increment()
        }

        router.pop()

        #expect(fired.calls == 0)
    }

    @Test("A root router has no parent and no children")
    func rootRouterHasNoParent() {
        let router = StackRouter(flow: FlowID("main"))

        #expect(router.parent == nil)
        #expect(router.root === router)
        #expect(router.flowID == FlowID("main"))
        #expect(router.children.isEmpty)
    }
}
