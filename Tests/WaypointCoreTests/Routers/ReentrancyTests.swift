//
//  ReentrancyTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Calls made while a change is applied are queued and run in order (see the Concurrency article).
@Suite("Re-entrant calls")
@MainActor
struct ReentrancyTests {
    @Test
    func callDuringChangeIsQueuedAndRunsAfter() {
        let router = StackRouter(configuration: .permissive)
        let inner = Recorder<NavigationOutcome>()
        let once = Once()
        router.tree.onApplied { changes in
            guard once.claim() else {
                return
            }
            inner.record(router.push(SettingsRoute()))
            let expectedPath = [AnyRoute(HomeRoute())]
            #expect(router.state.path == expectedPath)
        }

        let outer = router.push(HomeRoute())

        #expect(outer == .applied)
        let expectedOutcomes: [NavigationOutcome] = [.queued]
        #expect(inner.values == expectedOutcomes)
        let expectedPath2 = [AnyRoute(HomeRoute()), AnyRoute(SettingsRoute())]
        #expect(router.state.path == expectedPath2)
    }

    @Test
    func queuedCallsRunInOrderAcrossRouters() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        let once = Once()
        router.tree.onApplied { _ in
            guard once.claim() else {
                return
            }
            child.push(ProductRoute(id: 1))
            router.push(ProductRoute(id: 2))
            child.push(ProductRoute(id: 3))
        }

        router.push(HomeRoute())

        let expectedPath = [AnyRoute(ProductRoute(id: 1)), AnyRoute(ProductRoute(id: 3))]
        #expect(child.state.path == expectedPath)
        let expectedPath2 = [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 2))]
        #expect(router.state.path == expectedPath2)
    }

    @Test
    func queuedFailureIsReportedWhenItRuns() {
        let router = StackRouter(configuration: .permissive)
        let reported = Recorder<NavigationIssue.Kind>()
        let once = Once()
        router.tree.onReported { issue in
            reported.record(issue.kind)
        }
        router.tree.onApplied { _ in
            guard once.claim() else {
                return
            }
            router.popTo(SettingsRoute())
        }

        router.push(HomeRoute())

        let expectedKinds: [NavigationIssue.Kind] = [.routeNotInPath]
        #expect(reported.values == expectedKinds)
    }

    @Test
    func loopStopsAfterMaxQueuedChanges() {
        let router = StackRouter(configuration: NavigationConfiguration(maxQueuedChanges: 4, registry: .permissive))
        let outcomes = Recorder<NavigationOutcome>()
        router.tree.onApplied { _ in
            outcomes.record(router.push(HomeRoute()))
        }

        router.push(HomeRoute())

        #expect(router.state.path.count == 5)
        #expect(outcomes.values.filter { $0 == .queued }.count == 4)
        #expect(outcomes.last?.failure?.issue.kind == .reentrantLoop)
    }

    @Test
    func maxQueuedChangesDefaultsTo32AndIsSharedByTheTree() throws {
        let router = StackRouter(configuration: NavigationConfiguration(maxQueuedChanges: 8, registry: .permissive))
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        #expect(NavigationConfiguration.default.maxQueuedChanges == 32)
        #expect(child.configuration.maxQueuedChanges == 8)
    }
}
