//
//  NavigationLoopTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointCore
import WaypointTestSupport

/// P9 and P30: a callback that navigates forever can't freeze or crash the app. The limit counts
/// the calls queued during one outermost call.
@Suite("Navigation loops")
@MainActor
struct NavigationLoopTests {
    /// The queue limit these tests set.
    private static let limit = 4

    /// More calls than the limit allows.
    private static let callCount = 10

    @Test
    func navigationLoopStopsAndReportsReentrantLoop() {
        let failures = Spy<NavigationIssue.Kind, Void>()
        let configuration = NavigationConfiguration(maxQueuedChanges: Self.limit, registry: .permissive) { failure in
            failures(failure.issue.kind)
        }
        let router = StackRouter(configuration: configuration)

        let outcomes = navigateDuringAChange(on: router, calls: Self.callCount)

        let queued = outcomes.filter { $0 == .queued }
        let refused = outcomes.compactMap { $0.failure?.issue.kind }
        let loops = [NavigationIssue.Kind](repeating: .reentrantLoop, count: Self.callCount - Self.limit)
        let reportedOnce: [NavigationIssue.Kind] = [.reentrantLoop]
        #expect(queued.count == Self.limit)
        #expect(refused == loops)
        #expect(failures.calls == reportedOnce)
        #expect(router.state.path.count == Self.limit)
    }

    @Test
    func appNavigatesNormallyAfterALoopIsStopped() {
        let configuration = NavigationConfiguration(maxQueuedChanges: Self.limit, registry: .permissive)
        let router = StackRouter(configuration: configuration)
        _ = navigateDuringAChange(on: router, calls: Self.callCount)
        router.popToRoot()

        let next = router.push(ItemRoute(id: 1))
        let outcomes = navigateDuringAChange(on: router, calls: Self.limit)

        #expect(next == .applied)
        #expect(outcomes.allSatisfy { $0 == .queued })
        #expect(router.state.path.count == 1 + Self.limit)
    }

    @Test
    func loopLimitCountsCallsPerOutermostCall() {
        let configuration = NavigationConfiguration(maxQueuedChanges: Self.limit, registry: .permissive)
        let router = StackRouter(configuration: configuration)

        let first = navigateDuringAChange(on: router, calls: Self.limit)
        let second = navigateDuringAChange(on: router, calls: Self.limit)

        #expect((first + second).allSatisfy { $0 == .queued })
        #expect(router.state.path.count == 2 * Self.limit)
    }
    @Test
    func queueLimitDefaultsTo32AndIsSharedByTheTree() throws {
        let configuration = NavigationConfiguration(maxQueuedChanges: Self.limit, registry: .permissive)
        let router = StackRouter(configuration: configuration)
        router.present(CartRoute())
        let child = try #require(router.presented)

        let outcomes = navigateDuringAChange(on: child, calls: Self.callCount)

        #expect(NavigationConfiguration.default.maxQueuedChanges == 32)
        #expect(child.configuration.maxQueuedChanges == Self.limit)
        #expect(outcomes.filter { $0 == .queued }.count == Self.limit)
    }

    @Test
    func failureHandlerThatNavigatesCannotOverflowAfterLoop() {
        let issues = Spy<NavigationIssue.Kind, Void>()
        let holder = RouterHolder()
        let configuration = NavigationConfiguration(maxQueuedChanges: 4, registry: .permissive) { failure in
            issues(failure.issue.kind)
            // Fails again on the empty path, so the handler is called again: a loop.
            holder.router?.pop()
        }
        let router = StackRouter(configuration: configuration)
        holder.router = router

        let outcome = router.pop()

        #expect(outcome.failure?.issue.kind == .emptyPath)
        #expect(issues.calls.contains(.reentrantLoop))
        #expect(router.state.path.isEmpty)
    }

    /// Makes `calls` pushes from inside a transaction, as an observer that navigates on every
    /// change would, and returns their outcomes.
    private func navigateDuringAChange(on router: StackRouter, calls: Int) -> [NavigationOutcome] {
        let outcomes = Spy<NavigationOutcome, Void>()
        router.transaction { _ in
            for id in 0..<calls {
                outcomes(router.push(ItemRoute(id: id)))
            }
        }
        return outcomes.calls
    }
}
