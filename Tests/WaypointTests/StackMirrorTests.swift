//
//  StackMirrorTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: the mirror uses only the core, so these run on Linux too.

import Testing
import Understudy
import WaypointTestSupport

@testable import Waypoint
@testable import WaypointCore

/// The binding between a stack router and what a SwiftUI stack shows (planning #265).
@Suite("Stack mirror")
@MainActor
struct StackMirrorTests {
    /// A mirror that holds changes mid-transition, as on iOS 17, and one that doesn't.
    nonisolated static let bothHoldModes = [true, false]

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

        clock.advance(by: .milliseconds(450))

        let expected = [AnyRoute(HomeRoute())]
        #expect(mirror.shown == expected)
        #expect(!mirror.isHoldingChange)
    }

    @Test
    func heldChangeIsLoggedOnceAtDebug() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
        }
        mirror.routerDidChange()
        clock.advance(by: .milliseconds(150))
        handler.removeAll()

        router.pop()
        mirror.routerDidChange()
        router.pop()
        mirror.routerDidChange()

        let held = handler.messages.filter { $0.category == .renderer }
        #expect(held.map(\.text) == ["heldChange flow=main wait=450ms"])
        #expect(held.map(\.level) == [.debug])
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
        #expect(!mirror.isHoldingChange)
    }

    // On a busy device, drawing a push can block the main actor for seconds, and iOS 17 runs the
    // push only after that (planning #373). A change that lands as the drawing ends is held until
    // the push that runs from then ends.
    @Test
    func transitionCountsFromWhenDrawingEnds() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        clock.block(for: .seconds(2))
        router.pop()
        mirror.routerDidChange()

        #expect(mirror.shown.count == 1)
        #expect(mirror.isHoldingChange)

        clock.advance(by: .milliseconds(599))

        #expect(mirror.shown.count == 1)

        clock.advance(by: .milliseconds(1))

        #expect(mirror.shown.isEmpty)
        #expect(!mirror.isHoldingChange)
    }

    @Test
    func replacementGoesBackThenForward() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
        }
        mirror.routerDidChange()
        clock.advance(by: .milliseconds(600))

        router.setPath {
            HomeRoute()
            ProductRoute(id: 4)
        }
        mirror.routerDidChange()

        let back = [AnyRoute(HomeRoute())]
        #expect(mirror.shown == back)
        #expect(mirror.isHoldingChange)

        clock.advance(by: .milliseconds(600))

        #expect(mirror.shown == router.state.path)
        #expect(!mirror.isHoldingChange)
    }

    @Test
    func replacementInOneStepOnLaterSystems() {
        let router = StackRouter(configuration: .permissive)
        let mirror = StackMirror(router: router, holdsTransitions: false, clock: ManualTransitionClock())
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        router.setPath {
            ProductRoute(id: 4)
        }
        mirror.routerDidChange()

        #expect(mirror.shown == router.state.path)
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
        #expect(!mirror.isHoldingChange)
        // Only the end of the push is waiting, to clear the duplicate push window (planning #344).
        #expect(clock.scheduledCount == 1)
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
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }

        mirror.screenDidShow(count: 1)

        let expected = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expected)
        #expect(mirror.shown == expected)
        #expect(batches.lastCall?.map(\.origin) == [.user])
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
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }

        mirror.screenDidShow(count: 0)

        #expect(router.state.path.isEmpty)
        #expect(batches.callCount == 1)
    }

    @Test
    func sameCountFromScreenChangesNothing() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let mirror = Self.holdingMirror(router, ManualTransitionClock())
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }

        mirror.screenDidShow(count: 1)

        #expect(batches.callCount == 0)
        #expect(mirror.redrawCount == 0)
    }

    @Test
    func pushFromScreenIsRefusedAndRedrawn() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let mirror = Self.holdingMirror(router, ManualTransitionClock())
        let reported = Spy<NavigationIssue.Kind, Void>()
        router.tree.onReported { issue in
            reported(issue.kind)
        }

        mirror.screenDidShow(count: 2)

        let expected = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expected)
        #expect(mirror.shown == expected)
        #expect(mirror.redrawCount == 1)
        #expect(reported.calls == [.rendererMismatch])
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

    @Test(arguments: Self.bothHoldModes)
    func doubleTapPushesOnce(holdsTransitions: Bool) {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = StackMirror(router: router, holdsTransitions: holdsTransitions, clock: clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        clock.advance(by: .milliseconds(120))
        let outcome = router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        #expect(outcome == .alreadyThere)
        let expected = [AnyRoute(ProductRoute(id: 1))]
        #expect(mirror.shown == expected)
        #expect(router.state.path == expected)
    }

    @Test
    func samePushAfterTheTransitionEndsGoesAhead() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.holdingMirror(router, clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        clock.advance(by: StackMirror.transitionDuration)
        let outcome = router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        #expect(outcome == .applied)
        #expect(mirror.shown.count == 2)
    }

    @Test
    func onlyTheNewestPushReportsItsEnd() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = StackMirror(router: router, holdsTransitions: false, clock: clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()
        router.pop()
        mirror.routerDidChange()

        clock.advance(by: .milliseconds(400))
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()
        clock.advance(by: .milliseconds(300))

        #expect(router.push(ProductRoute(id: 1)) == .alreadyThere)
    }

    @Test
    func showsAPushedChildFlowsScreensAfterItsMarker() throws {
        let router = StackRouter(configuration: .permissive)
        let mirror = StackMirror(router: router, holdsTransitions: false, clock: ManualTransitionClock())
        let child = MirrorFlowCoordinator()
        router.push(child) { _ in }
        child.router.push(ProductRoute(id: 1))

        mirror.routerDidChange()

        let marker = try #require(child.router.marker)
        let expected = [marker, AnyRoute(ProductRoute(id: 1))]
        #expect(mirror.shown == expected)
        #expect(!mirror.isMissingDestination(marker))
    }

    @Test
    func backInsideAPushedChildFlowPopsTheChild() {
        let router = StackRouter(configuration: .permissive)
        let child = MirrorFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        router.push(child) { result in
            results(result)
        }
        child.router.push(ProductRoute(id: 1))
        let mirror = Self.holdingMirror(router, ManualTransitionClock())

        mirror.screenDidShow(count: 1)
        let childPathAfterBack = child.router.state.path
        mirror.screenDidShow(count: 0)

        #expect(childPathAfterBack.isEmpty)
        #expect(router.state.path.isEmpty)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
        #expect(mirror.shown.isEmpty)
    }

    @Test
    func aChildFlowsPushIsReportedToTheChild() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = StackMirror(router: router, holdsTransitions: false, clock: clock)
        let child = MirrorFlowCoordinator()
        router.push(child) { _ in }
        mirror.routerDidChange()
        clock.advance(by: StackMirror.transitionDuration)

        child.router.push(ProductRoute(id: 1))
        mirror.routerDidChange()
        clock.advance(by: .milliseconds(100))

        #expect(child.router.push(ProductRoute(id: 1)) == .alreadyThere)
        #expect(router.push(HomeRoute()) == .applied)
    }
}

/// A child flow a test pushes on a stack the mirror draws.
///
/// Conformances:
/// - `FlowCoordinating`, so a stack router can push it.
@MainActor
private final class MirrorFlowCoordinator: FlowCoordinating {
    /// What the flow finishes with.
    typealias Output = String
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

    /// Moves the clock on, and runs the work that is due, in time order, each at its own time,
    /// as on a main actor that is free. Work that is already late runs at once.
    func advance(by duration: Duration) {
        let end = now + duration
        while let next = scheduled.indices.filter({ scheduled[$0].time <= end }).min(by: {
            scheduled[$0].time < scheduled[$1].time
        }) {
            let work = scheduled.remove(at: next)
            now = max(now, work.time)
            work.action()
        }
        now = end
    }

    /// Moves the clock on without running anything, as while drawing blocks the main actor.
    func block(for duration: Duration) {
        now += duration
    }
}
