//
//  StackNavigatorTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The `StackNavigator` handle: it navigates its router and owns nothing (planning #279, decision
/// 0004).
@Suite("Stack navigator")
@MainActor
struct StackNavigatorTests {
    @Test
    func stackNavigatorPushesOnRouter() {
        let viaRouter = StackRouter(configuration: .permissive)
        let viaNavigator = StackRouter(configuration: .permissive)
        let routerBatches = Recorder<[AppliedChange]>()
        let navigatorBatches = Recorder<[AppliedChange]>()
        viaRouter.tree.onApplied { changes in
            routerBatches.record(changes)
        }
        viaNavigator.tree.onApplied { changes in
            navigatorBatches.record(changes)
        }

        viaRouter.push(ProductRoute(id: 1))
        let outcome = viaNavigator.navigator.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
        #expect(viaNavigator.state.path == viaRouter.state.path)
        let routerChanges = routerBatches.values.flatMap { $0.map(\.change) }
        let navigatorChanges = navigatorBatches.values.flatMap { $0.map(\.change) }
        #expect(navigatorChanges == routerChanges)
    }

    @Test
    func stackNavigatorPops() {
        let router = StackRouter(configuration: .permissive)
        // The root screen's navigator, so popping the screens above doesn't make it stale.
        let navigation = router.navigator
        router.push(ProductRoute(id: 1))
        router.push(ProductRoute(id: 2))
        router.push(ProductRoute(id: 3))

        navigation.pop()
        #expect(router.state.path.count == 2)

        navigation.popTo(ProductRoute(id: 1))
        let first = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == first)

        navigation.popToRoot()
        #expect(router.state.path.isEmpty)
    }

    @Test
    func stackNavigatorPresentsAFlow() throws {
        let router = StackRouter(configuration: .permissive)

        let outcome = router.navigator.present(SettingsRoute(), style: .fullScreenCover)

        #expect(outcome == .applied)
        let presentation = try #require(router.state.presentation)
        #expect(presentation.route == AnyRoute(SettingsRoute()))
        #expect(presentation.style == .fullScreenCover)
    }

    @Test
    func dismissFlowFromChildHandle() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let settings = try #require(router.presented)
        let navigation = settings.navigator

        let outcome = navigation.dismissFlow()

        #expect(outcome == .applied)
        #expect(router.presented == nil)
        #expect(!navigation.isActive)
    }

    @Test
    func navigatorPassesTheFallback() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        let outcome = router.navigator.popTo(HomeRoute(), else: .popToRoot)

        #expect(outcome.recoveredIssue?.kind == .routeNotInPath)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func navigatorReportsTheCallersLine() throws {
        let router = StackRouter(configuration: .permissive)
        let line: UInt = #line + 1
        let outcome = router.navigator.pop()

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .emptyPath)
        #expect(failure.issue.line == line)
        #expect(failure.issue.callSite.hasPrefix("StackNavigatorTests.swift:"))
    }

    @Test
    func missingNavigatorFailsAndReports() throws {
        let reported = Recorder<NavigationIssue>()
        let message = "@StackNavigation found no Waypoint stack above it."
        let navigation = StackNavigator(missing: message) { issue in
            reported.record(issue)
        }

        let outcome = navigation.push(HomeRoute())

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .noRouterInScope)
        #expect(failure.issue.message == message)
        #expect(failure.issue.callSite.hasPrefix("StackNavigatorTests.swift:"))
        let expected = [failure.issue]
        #expect(reported.values == expected)
        #expect(!navigation.isActive)
    }

    @Test
    func viewModelNavigatesWithRealRouter() {
        let router = StackRouter(configuration: .permissive)
        let model = ProductListModel(navigation: router.navigator)

        model.select(productID: 42)

        let expected = [AnyRoute(ProductRoute(id: 42))]
        #expect(router.state.path == expected)
    }
}

/// A view model that imports only the core and takes a navigator, as apps write them.
@MainActor
private final class ProductListModel {
    /// Where the model navigates.
    let navigation: StackNavigator

    /// A model that navigates through `navigation`.
    init(navigation: StackNavigator) {
        self.navigation = navigation
    }

    /// Shows a product.
    func select(productID: Int) {
        navigation.push(ProductRoute(id: productID))
    }
}
