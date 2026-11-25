//
//  QueuedCallTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Testing
import Understudy
import WaypointCore
import WaypointTestSupport

/// P7, P8, P18 to P21: a call made during a change waits, then runs right after it.
///
/// Every check is made right after the outer call returns, with no `await` in between, so a call
/// that ran in a later turn would fail them.
@Suite("Calls made during a change")
@MainActor
struct QueuedCallTests {
    @Test("Navigating from the failure handler is queued and runs after the change")
    func navigatingFromFailureHandlerRunsAfterTheChange() {
        let holder = RouterHolder()
        let inner = Spy<NavigationOutcome, Void>()
        let pathsSeen = Spy<[AnyRoute], Void>()
        let configuration = NavigationConfiguration(registry: .permissive) { _ in
            guard let router = holder.router, inner.calls.isEmpty else {
                return
            }
            inner(router.push(ItemRoute(id: 1)))
            pathsSeen(router.state.path)
        }
        let router = StackRouter(configuration: configuration)
        holder.router = router

        router.pop()

        let expected = [AnyRoute(ItemRoute(id: 1))]
        let queued: [NavigationOutcome] = [.queued]
        let empty: [[AnyRoute]] = [[]]
        #expect(inner.calls == queued)
        #expect(pathsSeen.calls == empty)
        #expect(router.state.path == expected)
    }

    @Test("Navigating from a transaction body is queued and runs after the change")
    func navigatingFromTransactionBodyRunsAfterTheChange() {
        let router = StackRouter(configuration: .permissive)
        let inner = Spy<NavigationOutcome, Void>()

        router.transaction { transaction in
            transaction.push(ItemRoute(id: 1))
            inner(router.push(ItemRoute(id: 2)))
        }

        let expected = [AnyRoute(ItemRoute(id: 1)), AnyRoute(ItemRoute(id: 2))]
        let queued: [NavigationOutcome] = [.queued]
        #expect(inner.calls == queued)
        #expect(router.state.path == expected)
    }

    @Test("Navigating from a custom fallback is queued and runs after the change")
    func navigatingFromCustomFallbackRunsAfterTheChange() {
        let holder = RouterHolder()
        let inner = Spy<NavigationOutcome, Void>()
        let fallback = NavigationFallback.custom("showHome") { _, _ in
            guard let router = holder.router else {
                return
            }
            inner(router.push(ItemRoute(id: 1)))
        }
        let router = StackRouter(configuration: .permissive)
        holder.router = router

        router.popTo(CartRoute(), else: fallback)

        let expected = [AnyRoute(ItemRoute(id: 1))]
        let queued: [NavigationOutcome] = [.queued]
        #expect(inner.calls == queued)
        #expect(router.state.path == expected)
    }

    @Test("Calls made during a change run in the order they were made")
    func callsMadeDuringAChangeRunInTheOrderMade() {
        let router = StackRouter(configuration: .permissive)
        let ids = [1, 2, 3]

        router.transaction { _ in
            for id in ids {
                router.push(ItemRoute(id: id))
            }
        }

        let expected = ids.map { AnyRoute(ItemRoute(id: $0)) }
        #expect(router.state.path == expected)
    }

    @Test("Queued calls keep their order across routers")
    func queuedCallsKeepOrderAcrossRouters() throws {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.present(CartRoute())
        let child = try #require(router.presented)
        handler.removeAll()
        let first = ItemRoute(id: 1)
        let second = ItemRoute(id: 2)
        let third = ItemRoute(id: 3)

        router.transaction { _ in
            child.push(first)
            router.push(second)
            child.push(third)
        }

        let marks = [first, second, third].map(\.logMark)
        let changes = handler.texts.filter { $0.hasPrefix("pushed") }
        let order = marks.compactMap { mark in
            changes.firstIndex { $0.contains(mark) }
        }
        #expect(order.count == marks.count)
        #expect(order == order.sorted())
    }

    @Test("A queued call that fails is reported and runs its fallback")
    func queuedCallThatFailsReportsAndRunsItsFallback() {
        let holder = RouterHolder()
        let failures = Spy<NavigationIssue.Kind, Void>()
        let configuration = NavigationConfiguration(registry: .permissive) { failure in
            failures(failure.issue.kind)
        }
        let router = StackRouter(configuration: configuration)
        holder.router = router
        let recover = NavigationFallback.custom("showItem") { transaction, _ in
            transaction.push(ItemRoute(id: 9))
        }

        router.transaction { transaction in
            transaction.push(ItemRoute(id: 1))
            router.popTo(CartRoute(), else: recover)
            router.popTo(CartRoute(), else: NavigationFallback.none)
        }

        let expected = [AnyRoute(ItemRoute(id: 1)), AnyRoute(ItemRoute(id: 9))]
        let kinds: [NavigationIssue.Kind] = [.routeNotInPath]
        #expect(router.state.path == expected)
        #expect(failures.calls == kinds)
    }

    @Test("A queued call is logged at debug with its call site")
    func queuedCallLogsReentrantChangeWithItsLine() throws {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        let callLine: UInt = 70_001

        router.transaction { _ in
            router.push(ItemRoute(id: 1), line: callLine)
        }

        let message = try #require(handler.messages.first { $0.text.hasPrefix("reentrantChange") })
        #expect(message.level == .debug)
        #expect(message.line == callLine)
        #expect("\(message.file)" == #fileID)
    }

    @Test("Queued and stale calls don't call the failure handler")
    func queuedAndStaleCallsDoNotCallTheFailureHandler() throws {
        let failures = Spy<NavigationFailure, Void>()
        let configuration = NavigationConfiguration(registry: .permissive) { failure in
            failures(failure)
        }
        let router = StackRouter(configuration: configuration)
        router.present(CartRoute())
        let child = try #require(router.presented)
        let navigation = child.navigator

        let queued = Spy<NavigationOutcome, Void>()
        router.transaction { _ in
            queued(router.push(ItemRoute(id: 1)))
        }
        router.dismiss()
        let stale = navigation.push(ItemRoute(id: 2))

        let expectedQueued: [NavigationOutcome] = [.queued]
        #expect(queued.calls == expectedQueued)
        #expect(stale == .ignored)
        #expect(failures.calls.isEmpty)
    }

    @Test("A transaction across two routers is seen whole")
    func twoRouterTransactionIsSeenWhole() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        let child = try #require(router.presented)
        let seen = Spy<Bool, Void>()
        let routerSees: @MainActor @Sendable () -> Void = {
            seen(router.state.path.isEmpty == child.state.path.isEmpty)
        }
        observeOnce(router, then: routerSees)
        observeOnce(child, then: routerSees)

        router.transaction { transaction in
            transaction.push(ItemRoute(id: 1))
            transaction.presented?.push(ItemRoute(id: 2))
        }

        let whole = [true, true]
        #expect(seen.calls == whole)
        #expect(router.state.path.count == 1)
        #expect(child.state.path.count == 1)
    }

    @Test("A queued call whose flow closed first is ignored")
    func queuedCallWhoseFlowClosedFirstIsIgnored() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        let child = try #require(router.presented)
        let late = Spy<NavigationOutcome, Void>()

        router.transaction { _ in
            router.dismiss()
            late(child.push(ItemRoute(id: 1)))
        }

        let queued: [NavigationOutcome] = [.queued]
        #expect(late.calls == queued)
        #expect(router.presented == nil)
        #expect(child.state.path.isEmpty)
        #expect(!child.isActive)
    }

    /// Calls `then` once, when `router`'s state is about to change, as an app's observer would.
    private func observeOnce(_ router: StackRouter, then: @escaping @MainActor @Sendable () -> Void) {
        withObservationTracking {
            _ = router.state
        } onChange: {
            MainActor.assumeIsolated {
                then()
            }
        }
    }
}
