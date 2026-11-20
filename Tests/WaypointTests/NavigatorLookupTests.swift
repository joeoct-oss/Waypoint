//
//  NavigatorLookupTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: the lookup uses only the core, so these run on Linux too.

import Testing
import WaypointTestSupport

@testable import Waypoint
@testable import WaypointCore

/// What the property wrappers find in the environment (#25, decision 0004).
@Suite("Navigator lookup")
@MainActor
struct NavigatorLookupTests {
    /// Where the wrappers in these tests are declared.
    let site = WrapperSite(file: "Shop/ProductView.swift", line: 12)

    @Test
    func environmentProvidesNearestRouter() {
        let outer = StackRouter(configuration: .permissive)
        let inner = StackRouter(configuration: .permissive)
        let reported = Recorder<NavigationIssue>()

        let navigation = NavigatorLookup.stack(inner, site: site, report: reported.record)
        navigation.push(HomeRoute())

        let expected = [AnyRoute(HomeRoute())]
        #expect(inner.state.path == expected)
        #expect(outer.state.path.isEmpty)
        #expect(reported.count == 0)
    }

    @Test
    func flowNavigationFindsTheNearestStackOfItsFlow() {
        let shop = StackRouter(configuration: .permissive)
        shop.declareFlow(ShopFlow.self)
        let settings = StackRouter(configuration: .permissive)
        settings.declareFlow(SettingsFlow.self)
        let undeclared = StackRouter(configuration: .permissive)
        // A settings sheet drawn inside the shop stack, then a plain stack inside that.
        let routers = FlowRouters().adding(shop).adding(settings).adding(undeclared)
        let reported = Recorder<NavigationIssue>()

        let navigation = NavigatorLookup.flow(ShopFlow.self, in: routers, site: site, report: reported.record)
        navigation.push(CartRoute())

        let expected = [AnyRoute(CartRoute())]
        #expect(shop.state.path == expected)
        #expect(settings.state.path.isEmpty)
        #expect(undeclared.state.path.isEmpty)
        #expect(reported.count == 0)
    }

    @Test
    func innerStackOfTheSameFlowWins() {
        let outer = StackRouter(configuration: .permissive)
        outer.declareFlow(ShopFlow.self)
        let inner = StackRouter(configuration: .permissive)
        inner.declareFlow(ShopFlow.self)

        let routers = FlowRouters().adding(outer).adding(inner)

        #expect(routers.router(for: ShopFlow.self) === inner)
        #expect(routers.router(for: SettingsFlow.self) == nil)
    }

    @Test
    func missingRouterReportsIssue() throws {
        let reported = Recorder<NavigationIssue>()
        let navigation = NavigatorLookup.stack(nil, site: site, report: reported.record)

        let outcome = navigation.push(HomeRoute())

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .noRouterInScope)
        let expectedMessage = "@StackNavigation in ProductView.swift:12 found no Waypoint stack above "
            + "its view. Show the view inside a WaypointStack, or add .waypointPreview() in its preview."
        #expect(failure.issue.message == expectedMessage)
        #expect(reported.count == 1)
        #expect(!navigation.isActive)
    }

    @Test
    func missingFlowReportsIssueNamingTheFlow() throws {
        let shop = StackRouter(configuration: .permissive)
        shop.declareFlow(ShopFlow.self)
        let routers = FlowRouters().adding(shop)
        let reported = Recorder<NavigationIssue>()
        let navigation = NavigatorLookup.flow(SettingsFlow.self, in: routers, site: site, report: reported.record)

        let outcome = navigation.push(PrivacyRoute())

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .noRouterInScope)
        let expectedMessage = "@FlowNavigation(SettingsFlow.self) in ProductView.swift:12 found no "
            + "SettingsFlow stack above its view. Declare one with WaypointStack(flow: SettingsFlow.self), "
            + "or add .waypointPreview(flow: SettingsFlow.self) in its preview."
        #expect(failure.issue.message == expectedMessage)
        #expect(reported.count == 1)
        #expect(shop.state.path.isEmpty)
    }

    @Test
    func destinationGetsItsStacksNavigator() {
        let router = StackRouter(configuration: .permissive)
        let reported = Recorder<NavigationIssue>()
        let product = ProductRoute(id: 1)
        router.push(product)

        let navigation = NavigatorLookup.destination(router, route: product, report: reported.record)
        navigation.push(HomeRoute())

        let expected = [AnyRoute(product), AnyRoute(HomeRoute())]
        #expect(router.state.path == expected)
        #expect(reported.count == 0)
    }

    @Test
    func destinationNavigatorGoesInactiveWhenItsScreenIsPopped() {
        let router = StackRouter(configuration: .permissive)
        let product = ProductRoute(id: 1)
        router.push(product)
        let navigation = NavigatorLookup.destination(router, route: product, report: { _ in })
        router.push(HomeRoute())
        #expect(navigation.isActive)

        router.popToRoot()
        let outcome = navigation.push(SettingsRoute())

        #expect(!navigation.isActive)
        #expect(outcome == .ignored)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func wrapperNavigatorsLiveAsLongAsTheFlow() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let navigation = NavigatorLookup.stack(router, site: site, report: { _ in })

        router.popToRoot()
        navigation.push(HomeRoute())

        let expected = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expected)
    }

    @Test
    func destinationOutsideAStackReportsIssue() throws {
        let reported = Recorder<NavigationIssue>()
        let navigation = NavigatorLookup.destination(nil, route: ProductRoute(id: 1), report: reported.record)

        let outcome = navigation.push(HomeRoute())

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .noRouterInScope)
        #expect(failure.issue.message.hasPrefix("destination(ProductRoute.self) is not inside a Waypoint stack"))
        #expect(reported.count == 1)
    }

    @Test
    func dismissFlowDismissesThePresentedFlow() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let settings = try #require(router.presented)
        let reported = Recorder<NavigationIssue>()
        let dismissFlow = NavigatorLookup.dismissFlow(settings, site: site, report: reported.record)

        let outcome = dismissFlow()

        #expect(outcome == .applied)
        #expect(router.presented == nil)
        #expect(!dismissFlow.isActive)
        #expect(reported.count == 0)
    }

    @Test
    func dismissFlowOnTheFirstStackFails() throws {
        let router = StackRouter(configuration: .permissive)
        let dismissFlow = NavigatorLookup.dismissFlow(router, site: site) { _ in
            Issue.record("A router was in scope.")
        }

        let outcome = dismissFlow()

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .notPresented)
    }

    @Test
    func dismissFlowWithNoStackReportsIssue() throws {
        let reported = Recorder<NavigationIssue>()
        let dismissFlow = NavigatorLookup.dismissFlow(nil, site: site, report: reported.record)

        let outcome = dismissFlow()

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .noRouterInScope)
        #expect(failure.issue.message.hasPrefix("@DismissFlow in ProductView.swift:12 found no Waypoint stack"))
        #expect(reported.count == 1)
    }
}
