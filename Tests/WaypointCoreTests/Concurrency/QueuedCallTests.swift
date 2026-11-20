//
//  QueuedCallTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Testing
import WaypointCore
import WaypointTestSupport

/// P7, P8, P18 to P21: a call made during a change waits, then runs right after it.
///
/// Every check is made right after the outer call returns, with no `await` in between, so a call
/// that ran in a later turn would fail them.
@Suite("Calls made during a change")
@MainActor
struct QueuedCallTests {
    @Test
    func navigatingFromFailureHandlerRunsAfterTheChange() {
        let holder = RouterHolder()
        let inner = Recorder<NavigationOutcome>()
        let pathsSeen = Recorder<[AnyRoute]>()
        let configuration = NavigationConfiguration(registry: .permissive) { _ in
            guard let router = holder.router, inner.values.isEmpty else {
                return
            }
            inner.record(router.push(ItemRoute(id: 1)))
            pathsSeen.record(router.state.path)
        }
        let router = StackRouter(configuration: configuration)
        holder.router = router

        router.pop()

        let expected = [AnyRoute(ItemRoute(id: 1))]
        let queued: [NavigationOutcome] = [.queued]
        let empty: [[AnyRoute]] = [[]]
        #expect(inner.values == queued)
        #expect(pathsSeen.values == empty)
        #expect(router.state.path == expected)
    }

    @Test
    func navigatingFromTransactionBodyRunsAfterTheChange() {
        let router = StackRouter(configuration: .permissive)
        let inner = Recorder<NavigationOutcome>()

        router.transaction { transaction in
            transaction.push(ItemRoute(id: 1))
            inner.record(router.push(ItemRoute(id: 2)))
        }

        let expected = [AnyRoute(ItemRoute(id: 1)), AnyRoute(ItemRoute(id: 2))]
        let queued: [NavigationOutcome] = [.queued]
        #expect(inner.values == queued)
        #expect(router.state.path == expected)
    }

    @Test
    func navigatingFromCustomFallbackRunsAfterTheChange() {
        let holder = RouterHolder()
        let inner = Recorder<NavigationOutcome>()
        let fallback = NavigationFallback.custom("showHome") { _, _ in
            guard let router = holder.router else {
                return
            }
            inner.record(router.push(ItemRoute(id: 1)))
        }
        let router = StackRouter(configuration: .permissive)
        holder.router = router

        router.popTo(CartRoute(), else: fallback)

        let expected = [AnyRoute(ItemRoute(id: 1))]
        let queued: [NavigationOutcome] = [.queued]
        #expect(inner.values == queued)
        #expect(router.state.path == expected)
    }

    @Test
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

    @Test
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

    @Test
    func queuedCallThatFailsReportsAndRunsItsFallback() {
        let holder = RouterHolder()
        let failures = Recorder<NavigationIssue.Kind>()
        let configuration = NavigationConfiguration(registry: .permissive) { failure in
            failures.record(failure.issue.kind)
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
        #expect(failures.values == kinds)
    }

    @Test
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

    @Test
    func queuedAndStaleCallsDoNotCallTheFailureHandler() throws {
        let failures = Recorder<NavigationFailure>()
        let configuration = NavigationConfiguration(registry: .permissive) { failure in
            failures.record(failure)
        }
        let router = StackRouter(configuration: configuration)
        router.present(CartRoute())
        let child = try #require(router.presented)
        let navigation = child.navigator

        let queued = Recorder<NavigationOutcome>()
        router.transaction { _ in
            queued.record(router.push(ItemRoute(id: 1)))
        }
        router.dismiss()
        let stale = navigation.push(ItemRoute(id: 2))

        let expectedQueued: [NavigationOutcome] = [.queued]
        #expect(queued.values == expectedQueued)
        #expect(stale == .ignored)
        #expect(failures.values.isEmpty)
    }

    @Test
    func twoRouterTransactionIsSeenWhole() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        let child = try #require(router.presented)
        let seen = Recorder<Bool>()
        let routerSees: @MainActor @Sendable () -> Void = {
            seen.record(router.state.path.isEmpty == child.state.path.isEmpty)
        }
        observeOnce(router, then: routerSees)
        observeOnce(child, then: routerSees)

        router.transaction { transaction in
            transaction.push(ItemRoute(id: 1))
            transaction.presented?.push(ItemRoute(id: 2))
        }

        let whole = [true, true]
        #expect(seen.values == whole)
        #expect(router.state.path.count == 1)
        #expect(child.state.path.count == 1)
    }

    @Test
    func queuedCallWhoseFlowClosedFirstIsIgnored() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        let child = try #require(router.presented)
        let late = Recorder<NavigationOutcome>()

        router.transaction { _ in
            router.dismiss()
            late.record(child.push(ItemRoute(id: 1)))
        }

        let queued: [NavigationOutcome] = [.queued]
        #expect(late.values == queued)
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
