//
//  DuplicatePushTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The duplicate push rule: a double tap pushes one screen (#142).
@Suite("Duplicate push rule")
@MainActor
struct DuplicatePushTests {
    /// A router with `route` pushed, while the renderer still animates that push.
    private static func routerPushing(_ route: ProductRoute) -> StackRouter {
        let router = StackRouter(configuration: .permissive)
        router.push(route)
        router.rendererDidStartPush(of: AnyRoute(route))
        return router
    }

    @Test
    func secondEqualPushInFlightIsSkipped() {
        let route = ProductRoute(id: 1)
        let router = Self.routerPushing(route)

        let outcome = router.push(route)

        #expect(outcome == .alreadyThere)
        let expectedPath = [AnyRoute(route)]
        #expect(router.state.path == expectedPath)
    }

    @Test
    func equalPushAfterTransitionEndsIsPushed() {
        let route = ProductRoute(id: 1)
        let router = Self.routerPushing(route)
        router.rendererDidEndPush(of: AnyRoute(route))

        let outcome = router.push(route)

        #expect(outcome == .applied)
        #expect(router.state.path.count == 2)
    }

    @Test
    func equalPushWithoutRendererReportIsPushed() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        let outcome = router.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
        #expect(router.state.path.count == 2)
    }

    @Test
    func differentRouteInFlightIsPushed() {
        let router = Self.routerPushing(ProductRoute(id: 1))

        let outcome = router.push(ProductRoute(id: 2))

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(ProductRoute(id: 1)), AnyRoute(ProductRoute(id: 2))]
        #expect(router.state.path == expectedPath)
    }

    @Test
    func equalPushAfterPopIsPushed() {
        let route = ProductRoute(id: 1)
        let router = Self.routerPushing(route)
        router.pop()

        let outcome = router.push(route)

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(route)]
        #expect(router.state.path == expectedPath)
    }

    @Test
    func pushOfSeveralRoutesIsNeverSkipped() {
        let route = ProductRoute(id: 1)
        let router = Self.routerPushing(route)

        let outcome = router.push {
            route
            route
        }

        #expect(outcome == .applied)
        #expect(router.state.path.count == 3)
    }

    @Test
    func endReportOfAnOlderPushIsIgnored() {
        let router = Self.routerPushing(ProductRoute(id: 1))
        router.push(ProductRoute(id: 2))
        router.rendererDidStartPush(of: AnyRoute(ProductRoute(id: 2)))
        router.rendererDidEndPush(of: AnyRoute(ProductRoute(id: 1)))

        let outcome = router.push(ProductRoute(id: 2))

        #expect(outcome == .alreadyThere)
    }

    @Test
    func allowRulePushesBoth() {
        let route = ProductRoute(id: 1)
        let router = Self.routerPushing(route)
        router.setDuplicatePushRule(.allow)

        let outcome = router.push(route)

        #expect(outcome == .applied)
        #expect(router.state.path.count == 2)
    }

    @Test
    func skipWhileInFlightIsTheDefault() {
        let router = StackRouter(configuration: .permissive)

        #expect(router.duplicatePushRule == .skipWhileInFlight)
    }

    @Test
    func ruleScopesToFlowAndChildren() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        child.setDuplicatePushRule(.allow)
        child.present(HomeRoute())
        let grandchild = try #require(child.presented)

        #expect(router.duplicatePushRule == .skipWhileInFlight)
        #expect(child.duplicatePushRule == .allow)
        #expect(grandchild.duplicatePushRule == .allow)
    }

    @Test
    func tabRuleReachesItsStacks() {
        let tabs = TabRouter(selection: MainTab.shop, configuration: .permissive)
        tabs.setDuplicatePushRule(.allow)

        let shop = tabs.router(for: .shop)

        #expect(shop.duplicatePushRule == .allow)
    }

    @Test
    func readableLogNamesTheSkippedPush() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration().withHandler(handler).withMinimumLevel(.debug)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(HomeRoute())
        router.rendererDidStartPush(of: AnyRoute(HomeRoute()))

        router.push(HomeRoute())

        let text = handler.texts.last ?? ""
        #expect(text.hasPrefix("Waypoint  main       skip     Home is still being pushed (DuplicatePushTests.swift:"))
        #expect(handler.messages.last?.level == .debug)
    }

    @Test
    func structuredLogNamesTheSkippedPush() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(format: .structured).withHandler(handler).withMinimumLevel(.debug)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(HomeRoute())
        router.rendererDidStartPush(of: AnyRoute(HomeRoute()))

        router.push(HomeRoute())

        let text = handler.texts.last ?? ""
        #expect(text.hasPrefix("alreadyThere flow=main skippedPush=HomeRoute"))
    }
}
