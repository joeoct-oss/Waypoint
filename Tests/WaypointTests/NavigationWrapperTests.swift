//
//  NavigationWrapperTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Understudy

// Draws real SwiftUI views in a window, so these run on the iOS simulator only. The lookup rules
// behind the wrappers are tested on Linux in `NavigatorLookupTests`.

#if canImport(UIKit) && canImport(SwiftUI)
    import SwiftUI
    import Testing
    import UIKit
    import WaypointTestSupport

    @testable import Waypoint
    @testable import WaypointCore

    /// The navigation property wrappers, the flow stack, the navigator destination and the preview
    /// helper, read from a real SwiftUI environment (planning #279, decision 0004).
    @Suite("Navigation wrappers")
    @MainActor
    struct NavigationWrapperTests {
        /// The longest a test waits for SwiftUI to draw a pushed screen.
        static let drawTimeout = Duration.seconds(2)

        /// Draws `view` in a window and lays it out once. Keep the window until the test ends.
        static func host(_ view: some View) -> UIWindow {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            return window
        }

        /// Lays the window out until `condition` holds or the draw timeout passes.
        static func waitUntil(_ window: UIWindow, _ condition: () -> Bool) async throws {
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: drawTimeout)
            while !condition(), clock.now < deadline {
                window.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(20))
            }
        }

        @Test("StackNavigation navigates the nearest router")
        func environmentProvidesNearestRouter() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Spy<StackNavigator, Void>()
            let window = Self.host(
                WaypointStack(router) {
                    StackProbe(seen: seen)
                }
            )

            let navigation = try #require(seen.lastCall)
            let outcome = navigation.push(HomeRoute())

            #expect(outcome == .applied)
            let expected = [AnyRoute(HomeRoute())]
            #expect(router.state.path == expected)
            withExtendedLifetime(window) { }
        }

        @Test("The environment still offers the router")
        func environmentStillOffersTheRouter() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Spy<StackRouter, Void>()
            let window = Self.host(
                WaypointStack(router) {
                    RouterProbe(seen: seen)
                }
            )

            #expect(seen.lastCall === router)
            withExtendedLifetime(window) { }
        }

        @Test("A flow stack declares its flow for FlowNavigation")
        func flowStackDeclaresItsFlowForFlowNavigation() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Spy<FlowNavigator<ShopFlow>, Void>()
            let window = Self.host(
                WaypointStack(flow: ShopFlow.self, router: router) {
                    ShopProbe(seen: seen)
                }
            )

            let shop = try #require(seen.lastCall)
            let outcome = shop.push(CartRoute())

            #expect(router.declaredFlow == ShopFlow.self)
            #expect(outcome == .applied)
            let expected = [AnyRoute(CartRoute())]
            #expect(router.state.path == expected)
            withExtendedLifetime(window) { }
        }

        @Test("FlowNavigation ignores a stack of another flow and reports it")
        func flowNavigationIgnoresAStackOfAnotherFlow() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Spy<FlowNavigator<ShopFlow>, Void>()
            let window = Self.host(
                WaypointStack(flow: SettingsFlow.self, router: router) {
                    ShopProbe(seen: seen)
                }
            )

            let shop = try #require(seen.lastCall)
            let outcome = shop.push(CartRoute())

            let failure = try #require(outcome.failure)
            #expect(failure.issue.kind == .noRouterInScope)
            #expect(failure.issue.message.hasPrefix("@FlowNavigation(ShopFlow.self) in NavigationWrapperTests.swift:"))
            #expect(router.state.path.isEmpty)
            withExtendedLifetime(window) { }
        }

        @Test("StackNavigation with no router reports an issue")
        func missingRouterReportsIssue() throws {
            let seen = Spy<StackNavigator, Void>()
            let window = Self.host(StackProbe(seen: seen))

            let navigation = try #require(seen.lastCall)
            let outcome = navigation.push(HomeRoute())

            let failure = try #require(outcome.failure)
            #expect(failure.issue.kind == .noRouterInScope)
            #expect(failure.issue.message.hasPrefix("@StackNavigation in NavigationWrapperTests.swift:"))
            #expect(!navigation.isActive)
            withExtendedLifetime(window) { }
        }

        @Test("DismissFlow dismisses the stack's flow")
        func dismissFlowDismissesTheStacksFlow() throws {
            let root = StackRouter(configuration: .permissive)
            root.present(SettingsRoute())
            let settings = try #require(root.presented)
            let seen = Spy<DismissFlowAction, Void>()
            let window = Self.host(
                WaypointStack(settings) {
                    DismissProbe(seen: seen)
                }
            )

            let dismissFlow = try #require(seen.lastCall)
            let outcome = dismissFlow()

            #expect(outcome == .applied)
            #expect(root.presented == nil)
            withExtendedLifetime(window) { }
        }

        @Test("The preview helper provides working routers")
        func previewHelperProvidesRouters() throws {
            let stackSeen = Spy<StackNavigator, Void>()
            let shopSeen = Spy<FlowNavigator<ShopFlow>, Void>()
            let stackWindow = Self.host(StackProbe(seen: stackSeen).waypointPreview())
            let shopWindow = Self.host(ShopProbe(seen: shopSeen).waypointPreview(flow: ShopFlow.self))

            let navigation = try #require(stackSeen.lastCall)
            let shop = try #require(shopSeen.lastCall)

            #expect(navigation.push(HomeRoute()) == .applied)
            #expect(shop.push(CartRoute()) == .applied)
            withExtendedLifetime(stackWindow) { }
            withExtendedLifetime(shopWindow) { }
        }

        @Test("A destination hands the screen its navigator")
        func destinationHandsTheScreenItsNavigator() async throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Spy<StackNavigator, Void>()
            let window = Self.host(
                WaypointStack(router) {
                    Color.clear
                        .destination(ProductRoute.self) { _, navigation in
                            NavigatorProbe(navigation: navigation, seen: seen)
                        }
                }
            )

            router.push(ProductRoute(id: 1))
            try await Self.waitUntil(window) {
                seen.callCount > 0
            }

            let navigation = try #require(seen.lastCall)
            navigation.push(HomeRoute())
            let expected = [
                AnyRoute(ProductRoute(id: 1)),
                AnyRoute(HomeRoute()),
            ]
            #expect(router.state.path == expected)
        }
    }

    /// Records the `@StackNavigation` navigator each time it draws.
    private struct StackProbe: View {
        @StackNavigation private var navigation

        let seen: Spy<StackNavigator, Void>

        var body: some View {
            let _ = seen(navigation)
            Color.clear
        }
    }

    /// Records the `@FlowNavigation(ShopFlow.self)` navigator each time it draws.
    private struct ShopProbe: View {
        @FlowNavigation(ShopFlow.self) private var shop

        let seen: Spy<FlowNavigator<ShopFlow>, Void>

        var body: some View {
            let _ = seen(shop)
            Color.clear
        }
    }

    /// Records the `@DismissFlow` action each time it draws.
    private struct DismissProbe: View {
        @DismissFlow private var dismissFlow

        let seen: Spy<DismissFlowAction, Void>

        var body: some View {
            let _ = seen(dismissFlow)
            Color.clear
        }
    }

    /// Records the router `@Environment(StackRouter.self)` gives each time it draws.
    private struct RouterProbe: View {
        @Environment(StackRouter.self) private var router

        let seen: Spy<StackRouter, Void>

        var body: some View {
            let _ = seen(router)
            Color.clear
        }
    }

    /// Records the navigator a destination closure handed it each time it draws.
    private struct NavigatorProbe: View {
        let navigation: StackNavigator
        let seen: Spy<StackNavigator, Void>

        var body: some View {
            let _ = seen(navigation)
            Color.clear
        }
    }
#endif
