//
//  MissingDestinationTests.swift
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

/// How a stack finds a route it shows with no destination of its own (planning #361).
@Suite("Missing destinations")
@MainActor
struct MissingDestinationTests {
    /// A mirror on a clock moved by hand, for a router that shows routes with no destination.
    private static func makeMirror(_ router: StackRouter, _ clock: ManualTransitionClock) -> StackMirror {
        StackMirror(router: router, holdsTransitions: false, clock: clock)
    }

    /// The issues `router`'s tree reports from now on.
    private static func recordIssues(of router: StackRouter) -> Recorder<NavigationIssue> {
        let reported = Recorder<NavigationIssue>()
        router.tree.onReported { issue in
            reported.record(issue)
        }
        return reported
    }

    @Test
    func routeWithADestinationInTheStackIsNotMissing() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.makeMirror(router, clock)
        let reported = Self.recordIssues(of: router)
        mirror.registerDestination(ProductRoute.self)

        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()
        clock.advance(by: StackMirror.transitionDuration)

        #expect(mirror.missingDestinations.isEmpty)
        #expect(!mirror.isMissingDestination(AnyRoute(ProductRoute(id: 1))))
        #expect(reported.count == 0)
    }

    @Test
    func routeWithNoDestinationInTheStackIsMissingOnceThePushEnds() throws {
        let router = StackRouter(flow: FlowID("shop"), configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.makeMirror(router, clock)
        let reported = Self.recordIssues(of: router)
        mirror.registerDestination(HomeRoute.self)

        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        #expect(mirror.missingDestinations.isEmpty)

        clock.advance(by: StackMirror.transitionDuration)

        let issue = try #require(mirror.missingDestinations[ProductRoute.routeKey])
        #expect(issue.kind == .missingDestination)
        #expect(issue.flow == FlowID("shop"))
        #expect(mirror.isMissingDestination(AnyRoute(ProductRoute(id: 1))))
        let expectedIssues = [issue]
        #expect(reported.values == expectedIssues)
    }

    @Test
    func aMissingTypeIsReportedOnce() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.makeMirror(router, clock)
        let reported = Self.recordIssues(of: router)

        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()
        clock.advance(by: StackMirror.transitionDuration)
        router.push(ProductRoute(id: 2))
        mirror.routerDidChange()
        clock.advance(by: StackMirror.transitionDuration)

        #expect(mirror.missingDestinations.count == 1)
        #expect(reported.count == 1)
    }

    @Test
    func aDestinationRegisteredLaterClearsTheMissingType() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.makeMirror(router, clock)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()
        clock.advance(by: StackMirror.transitionDuration)

        mirror.registerDestination(ProductRoute.self)

        #expect(!mirror.missingDestinations.isEmpty)

        clock.advance(by: .zero)

        #expect(mirror.missingDestinations.isEmpty)
    }

    @Test
    func aRestoredPathIsCheckedOnceTheStackIsDrawn() {
        let router = StackRouter(configuration: .permissive)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
        }
        let clock = ManualTransitionClock()
        let mirror = Self.makeMirror(router, clock)
        mirror.registerDestination(HomeRoute.self)

        mirror.stackDidAppear()
        clock.advance(by: StackMirror.transitionDuration)

        let missing = Array(mirror.missingDestinations.keys)
        let expected = [ProductRoute.routeKey]
        #expect(missing == expected)
        #expect(!mirror.isMissingDestination(AnyRoute(HomeRoute())))
    }

    @Test
    func aMirrorThatNeverAppearsReportsNothing() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let reported = Self.recordIssues(of: router)
        let clock = ManualTransitionClock()
        let mirror = Self.makeMirror(router, clock)

        clock.advance(by: StackMirror.transitionDuration)

        #expect(mirror.missingDestinations.isEmpty)
        #expect(reported.count == 0)
        #expect(clock.scheduledCount == 0)
    }

    @Test
    func aPopChecksNothing() {
        let router = StackRouter(configuration: .permissive)
        let clock = ManualTransitionClock()
        let mirror = Self.makeMirror(router, clock)
        let reported = Self.recordIssues(of: router)
        router.push(ProductRoute(id: 1))
        mirror.routerDidChange()

        router.pop()
        mirror.routerDidChange()
        clock.advance(by: StackMirror.transitionDuration)

        #expect(mirror.missingDestinations.isEmpty)
        #expect(reported.count == 0)
    }
}
