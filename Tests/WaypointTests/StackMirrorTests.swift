//
//  StackMirrorTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: the mirror uses only the core, so these run on Linux too.

import Testing
import WaypointTestSupport

@testable import Waypoint
@testable import WaypointCore

/// The binding between a stack router and what a SwiftUI stack shows (#11).
@Suite("Stack mirror")
@MainActor
struct StackMirrorTests {
    /// A mirror that holds changes mid-transition, as on iOS 17, on a clock moved by hand.
    private static func holdingMirror(_ router: StackRouter, _ clock: ManualTransitionClock) -> StackMirror {
        StackMirror(router: router, holdsTransitions: true, clock: clock)
    }

    @Test
    func showsRouterPathFromTheStart() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        let mirror = Self.holdingMirror(router, ManualTransitionClock())

        let expected = [AnyRoute(ProductRoute(id: 1))]
        #expect(mirror.shown == expected)
    }

    @Test
    func pushShowsAtOnceWhenNoTransitionRuns() {
        let router = StackRouter(configuration: .permissive)
        let mirror = Self.holdingMirror(router, ManualTransitionClock())

        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        #expect(mirror.shown == router.state.path)
        #expect(!mirror.isHoldingChange)
    }

    @Test
    func changeMidTransitionIsHeldThenNewestShown() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
            ProductRoute(id: 2)
        }
        mirror.routerDidChange()

        clock.advance(by: .milliseconds(150))
        router.pop()
        mirror.routerDidChange()
        router.pop()
        mirror.routerDidChange()

        #expect(mirror.shown.count == 3)
        #expect(mirror.isHoldingChange)
        #expect(clock.scheduledCount == 1)

        clock.advance(by: .milliseconds(450))

        let expected = [AnyRoute(HomeRoute())]
        #expect(mirror.shown == expected)
        #expect(!mirror.isHoldingChange)
    }

    @Test
    func changeAfterTransitionEndsShowsAtOnce() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        clock.advance(by: .milliseconds(600))
        router.pop()
        mirror.routerDidChange()

        #expect(mirror.shown.isEmpty)
        #expect(clock.scheduledCount == 0)
    }

    @Test
    func noHoldOnLaterSystems() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = StackMirror(router: router, holdsTransitions: false, clock: clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        router.pop()
        mirror.routerDidChange()

        #expect(mirror.shown.isEmpty)
        #expect(clock.scheduledCount == 0)
    }

    @Test
    func holdThatEndsOnSamePathShowsNothingNew() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()
        router.push(ProductRoute(id: 2))
        mirror.routerDidChange()
        router.pop()

        clock.advance(by: .milliseconds(600))

        let expected = [AnyRoute(ProductRoute(id: 1))]
        #expect(mirror.shown == expected)
    }

    @Test
    func swipeBackReportsUserPop() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())
        router.push(ProductRoute(id: 1))
        let mirror = Self.holdingMirror(router, ManualTransitionClock())
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }

        mirror.screenDidShow(count: 1)

        let expected = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expected)
        #expect(mirror.shown == expected)
        #expect(batches.last?.map(\.origin) == [.user])
    }

    @Test
    func backMenuReportsOneMultiLevelPop() {
        let router = StackRouter(configuration: .permissive)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
            ProductRoute(id: 2)
        }
        let mirror = Self.holdingMirror(router, ManualTransitionClock())
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }

        mirror.screenDidShow(count: 0)

        #expect(router.state.path.isEmpty)
        #expect(batches.count == 1)
    }

    @Test
    func sameCountFromScreenChangesNothing() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let mirror = Self.holdingMirror(router, ManualTransitionClock())
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }

        mirror.screenDidShow(count: 1)

        #expect(batches.count == 0)
        #expect(mirror.redrawCount == 0)
    }

    @Test
    func pushFromScreenIsRefusedAndRedrawn() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let mirror = Self.holdingMirror(router, ManualTransitionClock())
        let reported = Recorder<NavigationIssue.Kind>()
        router.tree.onReported { issue in
            reported.record(issue.kind)
        }

        mirror.screenDidShow(count: 2)

        let expected = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expected)
        #expect(mirror.shown == expected)
        #expect(mirror.redrawCount == 1)
        #expect(reported.values == [.rendererMismatch])
    }

    @Test
    func userPopWhileHoldingKeepsOnlyWhatScreenShows() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
        }
        mirror.routerDidChange()
        router.setPath {
            SettingsRoute()
        }
        mirror.routerDidChange()

        mirror.screenDidShow(count: 1)

        let expected = [AnyRoute(HomeRoute())]
        #expect(mirror.shown == expected)
        #expect(router.state.path.isEmpty)

        clock.advance(by: .milliseconds(600))

        #expect(mirror.shown.isEmpty)
    }

    @Test
    func userPopStartsATransition() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        router.push(HomeRoute())
        router.push(ProductRoute(id: 1))
        let mirror = Self.holdingMirror(router, clock)

        mirror.screenDidShow(count: 1)
        clock.advance(by: .milliseconds(100))
        router.push(SettingsRoute())
        mirror.routerDidChange()

        #expect(mirror.shown.count == 1)
        #expect(mirror.isHoldingChange)
    }
}

/// A transition clock that only moves when a test moves it.
///
/// Conformances:
/// - `TransitionClock`, so a mirror can use it in tests.
@MainActor
final class ManualTransitionClock: TransitionClock {
    /// Work to run once the clock reaches its time.
    private struct Scheduled {
        /// When to run it.
        let time: Duration

        /// The work.
        let action: @MainActor () -> Void
    }

    /// The time since the clock started.
    ///
    /// `var` because the test moves it. Only ``advance(by:)`` changes it.
    private(set) var now = Duration.zero

    /// Work waiting for its time, in the order it was scheduled.
    ///
    /// `var` because work is added and run. Only ``run(after:_:)`` and ``advance(by:)`` change it.
    private var scheduled: [Scheduled] = []

    /// How much work is waiting.
    var scheduledCount: Int {
        scheduled.count
    }

    /// Keeps `action` until the clock reaches `now + delay`.
    func run(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        scheduled.append(Scheduled(time: now + delay, action: action))
    }

    /// Moves the clock on, and runs the work that is due, in order.
    func advance(by duration: Duration) {
        now += duration
        let due = scheduled.filter { $0.time <= now }
        scheduled.removeAll { $0.time <= now }
        for work in due {
            work.action()
        }
    }
}
