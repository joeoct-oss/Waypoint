//
//  FlowNavigatorTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// Flow scoping: `FlowNavigator<Flow>` takes only its flow's routes, and a stack can declare its
/// flow.
@Suite("Flow navigator")
@MainActor
struct FlowNavigatorTests {
    @Test("Routes belong to no flow by default")
    func routesAreUnscopedByDefault() {
        #expect(HomeRoute.Flow.self == AnyFlow.self)
        #expect(CartRoute.Flow.self == ShopFlow.self)
    }

    @Test("A flow navigator pushes its flow's routes")
    func flowNavigatorPushesOwnRoutes() {
        let router = StackRouter(configuration: .permissive)
        let shop = router.navigator(for: ShopFlow.self)

        let outcome = shop.push(CartRoute())

        #expect(outcome == .applied)
        let expected = [AnyRoute(CartRoute())]
        #expect(router.state.path == expected)
    }

    @Test("A flow navigator pops to its flow's routes")
    func flowNavigatorPopsToOwnRoutes() {
        let router = StackRouter(configuration: .permissive)
        let shop = router.navigator(for: ShopFlow.self)
        shop.push(CartRoute())
        shop.unscoped.push(HomeRoute())

        let outcome = shop.popTo(CartRoute())

        #expect(outcome == .applied)
        let expected = [AnyRoute(CartRoute())]
        #expect(router.state.path == expected)
    }

    @Test("The unscoped navigator pushes any route")
    func unscopedEscapeHatchPushesAnyRoute() {
        let router = StackRouter(configuration: .permissive)
        let shop = router.navigator(for: ShopFlow.self)

        let outcome = shop.unscoped.push(HomeRoute())

        #expect(outcome == .applied)
        let expected = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expected)
    }

    @Test("A flow navigator pops, presents and dismisses")
    func flowNavigatorPopsPresentsAndDismisses() throws {
        let router = StackRouter(configuration: .permissive)
        let shop = router.navigator(for: ShopFlow.self)
        shop.push(CartRoute())
        shop.push(CartRoute())

        shop.pop()
        #expect(router.state.path.count == 1)
        shop.popToRoot()
        #expect(router.state.path.isEmpty)

        shop.present(PrivacyRoute())
        let privacy = try #require(router.presented)
        let settings = privacy.navigator(for: SettingsFlow.self)
        #expect(settings.isActive)
        settings.dismissFlow()
        #expect(router.presented == nil)
        #expect(!settings.isActive)
        #expect(shop.isActive)
    }

    @Test("A navigator for the stack's declared flow reports nothing")
    func navigatorForTheDeclaredFlowReportsNothing() {
        let router = StackRouter(configuration: .permissive)
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }
        router.declareFlow(ShopFlow.self)

        let shop = router.navigator(for: ShopFlow.self)

        #expect(router.declaredFlow == ShopFlow.self)
        #expect(reported.callCount == 0)
        #expect(shop.isActive)
    }

    @Test("A navigator for a stack with no declared flow reports nothing")
    func navigatorForAnUndeclaredStackReportsNothing() {
        let router = StackRouter(configuration: .permissive)
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }

        _ = router.navigator(for: ShopFlow.self)

        #expect(router.declaredFlow == nil)
        #expect(reported.callCount == 0)
    }

    @Test("A navigator for another flow reports a mismatch and still navigates")
    func navigatorForAnotherFlowReportsMismatchAndStillNavigates() throws {
        let router = StackRouter(configuration: .permissive)
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }
        router.declareFlow(SettingsFlow.self)

        let line: UInt = #line + 1
        let shop = router.navigator(for: ShopFlow.self)
        let outcome = shop.push(CartRoute())

        let issue = try #require(reported.lastCall)
        #expect(issue.kind == .flowMismatch)
        #expect(issue.flow == router.flowID)
        #expect(issue.line == line)
        let expectedMessage = "navigator(for: ShopFlow.self) was asked of main, a stack declared for "
            + "SettingsFlow. The navigator works, but check that the screen is in the flow you meant."
        #expect(issue.message == expectedMessage)
        #expect(outcome == .applied)
    }

    @Test("Declaring another flow replaces the first")
    func declaringAnotherFlowReplacesTheFirst() {
        let router = StackRouter(configuration: .permissive)

        router.declareFlow(ShopFlow.self)
        router.declareFlow(SettingsFlow.self)

        #expect(router.declaredFlow == SettingsFlow.self)
    }

    @Test("A flow navigator made from a stack navigator works and reports a mismatch")
    func scopedNavigatorFromAStackNavigator() throws {
        let router = StackRouter(configuration: .permissive)
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }
        router.declareFlow(SettingsFlow.self)
        let navigation = router.navigator

        let settings = navigation.scoped(to: SettingsFlow.self)
        settings.push(PrivacyRoute())
        let line: UInt = #line + 1
        _ = navigation.scoped(to: ShopFlow.self)

        let expected = [AnyRoute(PrivacyRoute())]
        #expect(router.state.path == expected)
        let issue = try #require(reported.lastCall)
        #expect(reported.callCount == 1)
        #expect(issue.kind == .flowMismatch)
        #expect(issue.line == line)
    }

    @Test("A view model navigates its flow with a real router")
    func viewModelNavigatesWithRealRouter() {
        let router = StackRouter(configuration: .permissive)
        let model = ProductModel(navigation: router.navigator(for: ShopFlow.self))

        model.buy()

        let expected = [AnyRoute(CartRoute())]
        #expect(router.state.path == expected)
    }
}

/// A view model that only accepts shop routes, as apps write them.
@MainActor
private final class ProductModel {
    /// Where the model navigates.
    let navigation: FlowNavigator<ShopFlow>

    /// A model that navigates through `navigation`.
    init(navigation: FlowNavigator<ShopFlow>) {
        self.navigation = navigation
    }

    /// Opens the cart.
    func buy() {
        navigation.push(CartRoute())
    }
}
