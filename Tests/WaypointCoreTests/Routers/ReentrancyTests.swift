//
//  ReentrancyTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Calls made while a change is applied are queued and run in order (decision 0013).
@Suite("Re-entrant calls")
@MainActor
struct ReentrancyTests {
    @Test
    func callDuringChangeIsQueuedAndRunsAfter() {
        let router = StackRouter()
        var inner: NavigationOutcome?
        router.tree.didApply = { changes in
            guard inner == nil else {
                return
            }
            inner = router.push(SettingsRoute())
            #expect(router.state.path == [AnyRoute(HomeRoute())])
        }

        let outer = router.push(HomeRoute())

        #expect(outer == .applied)
        #expect(inner == .queued)
        #expect(router.state.path == [AnyRoute(HomeRoute()), AnyRoute(SettingsRoute())])
    }

    @Test
    func queuedCallsRunInOrderAcrossRouters() throws {
        let router = StackRouter()
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        var queued = false
        router.tree.didApply = { _ in
            guard !queued else {
                return
            }
            queued = true
            child.push(ProductRoute(id: 1))
            router.push(ProductRoute(id: 2))
            child.push(ProductRoute(id: 3))
        }

        router.push(HomeRoute())

        #expect(child.state.path == [AnyRoute(ProductRoute(id: 1)), AnyRoute(ProductRoute(id: 3))])
        #expect(router.state.path == [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 2))])
    }

    @Test
    func queuedFailureIsReportedWhenItRuns() {
        let router = StackRouter()
        var reported: [NavigationIssue.Kind] = []
        var queued = false
        router.tree.didReport = { issue in
            reported.append(issue.kind)
        }
        router.tree.didApply = { _ in
            guard !queued else {
                return
            }
            queued = true
            router.popTo(SettingsRoute())
        }

        router.push(HomeRoute())

        #expect(reported == [.routeNotInPath])
    }

    @Test
    func loopStopsAfterMaxQueuedChanges() {
        let router = StackRouter()
        router.maxQueuedChanges = 4
        var outcomes: [NavigationOutcome] = []
        router.tree.didApply = { _ in
            outcomes.append(router.push(HomeRoute()))
        }

        router.push(HomeRoute())

        #expect(router.state.path.count == 5)
        #expect(outcomes.filter { $0 == .queued }.count == 4)
        #expect(outcomes.last?.failure?.issue.kind == .reentrantLoop)
    }

    @Test
    func maxQueuedChangesDefaultsTo32AndIsSharedByTheTree() throws {
        let router = StackRouter()
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        #expect(router.maxQueuedChanges == 32)
        child.maxQueuedChanges = 8
        #expect(router.maxQueuedChanges == 8)
    }
}
