//
//  NavigationWrapperTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

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
    /// helper, read from a real SwiftUI environment (#25, decision 0004).
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

        @Test
        func environmentProvidesNearestRouter() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Recorder<StackNavigator>()
            let window = Self.host(
                WaypointStack(router) {
                    StackProbe(seen: seen)
                }
            )

            let navigation = try #require(seen.last)
            let outcome = navigation.push(HomeRoute())

            #expect(outcome == .applied)
            let expected = [AnyRoute(HomeRoute())]
            #expect(router.state.path == expected)
            withExtendedLifetime(window) { }
        }

        @Test
        func environmentStillOffersTheRouter() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Recorder<StackRouter>()
            let window = Self.host(
                WaypointStack(router) {
                    RouterProbe(seen: seen)
                }
            )

            #expect(seen.last === router)
            withExtendedLifetime(window) { }
        }

        @Test
        func flowStackDeclaresItsFlowForFlowNavigation() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Recorder<FlowNavigator<ShopFlow>>()
            let window = Self.host(
                WaypointStack(flow: ShopFlow.self, router: router) {
                    ShopProbe(seen: seen)
                }
            )

            let shop = try #require(seen.last)
            let outcome = shop.push(CartRoute())

            #expect(router.declaredFlow == ShopFlow.self)
            #expect(outcome == .applied)
            let expected = [AnyRoute(CartRoute())]
            #expect(router.state.path == expected)
            withExtendedLifetime(window) { }
        }

        @Test
        func flowNavigationIgnoresAStackOfAnotherFlow() throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Recorder<FlowNavigator<ShopFlow>>()
            let window = Self.host(
                WaypointStack(flow: SettingsFlow.self, router: router) {
                    ShopProbe(seen: seen)
                }
            )

            let shop = try #require(seen.last)
            let outcome = shop.push(CartRoute())

            let failure = try #require(outcome.failure)
            #expect(failure.issue.kind == .noRouterInScope)
            #expect(failure.issue.message.hasPrefix("@FlowNavigation(ShopFlow.self) in NavigationWrapperTests.swift:"))
            #expect(router.state.path.isEmpty)
            withExtendedLifetime(window) { }
        }

        @Test
        func missingRouterReportsIssue() throws {
            let seen = Recorder<StackNavigator>()
            let window = Self.host(StackProbe(seen: seen))

            let navigation = try #require(seen.last)
            let outcome = navigation.push(HomeRoute())

            let failure = try #require(outcome.failure)
            #expect(failure.issue.kind == .noRouterInScope)
            #expect(failure.issue.message.hasPrefix("@StackNavigation in NavigationWrapperTests.swift:"))
            #expect(!navigation.isActive)
            withExtendedLifetime(window) { }
        }

        @Test
        func dismissFlowDismissesTheStacksFlow() throws {
            let root = StackRouter(configuration: .permissive)
            root.present(SettingsRoute())
            let settings = try #require(root.presented)
            let seen = Recorder<DismissFlowAction>()
            let window = Self.host(
                WaypointStack(settings) {
                    DismissProbe(seen: seen)
                }
            )

            let dismissFlow = try #require(seen.last)
            let outcome = dismissFlow()

            #expect(outcome == .applied)
            #expect(root.presented == nil)
            withExtendedLifetime(window) { }
        }

        @Test
        func previewHelperProvidesRouters() throws {
            let stackSeen = Recorder<StackNavigator>()
            let shopSeen = Recorder<FlowNavigator<ShopFlow>>()
            let stackWindow = Self.host(StackProbe(seen: stackSeen).waypointPreview())
            let shopWindow = Self.host(ShopProbe(seen: shopSeen).waypointPreview(flow: ShopFlow.self))

            let navigation = try #require(stackSeen.last)
            let shop = try #require(shopSeen.last)

            #expect(navigation.push(HomeRoute()) == .applied)
            #expect(shop.push(CartRoute()) == .applied)
            withExtendedLifetime(stackWindow) { }
            withExtendedLifetime(shopWindow) { }
        }

        @Test
        func destinationHandsTheScreenItsNavigator() async throws {
            let router = StackRouter(configuration: .permissive)
            let seen = Recorder<StackNavigator>()
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
                seen.count > 0
            }

            let navigation = try #require(seen.last)
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

        let seen: Recorder<StackNavigator>

        var body: some View {
            let _ = seen.record(navigation)
            Color.clear
        }
    }

    /// Records the `@FlowNavigation(ShopFlow.self)` navigator each time it draws.
    private struct ShopProbe: View {
        @FlowNavigation(ShopFlow.self) private var shop

        let seen: Recorder<FlowNavigator<ShopFlow>>

        var body: some View {
            let _ = seen.record(shop)
            Color.clear
        }
    }

    /// Records the `@DismissFlow` action each time it draws.
    private struct DismissProbe: View {
        @DismissFlow private var dismissFlow

        let seen: Recorder<DismissFlowAction>

        var body: some View {
            let _ = seen.record(dismissFlow)
            Color.clear
        }
    }

    /// Records the router `@Environment(StackRouter.self)` gives each time it draws.
    private struct RouterProbe: View {
        @Environment(StackRouter.self) private var router

        let seen: Recorder<StackRouter>

        var body: some View {
            let _ = seen.record(router)
            Color.clear
        }
    }

    /// Records the navigator a destination closure handed it each time it draws.
    private struct NavigatorProbe: View {
        let navigation: StackNavigator
        let seen: Recorder<StackNavigator>

        var body: some View {
            let _ = seen.record(navigation)
            Color.clear
        }
    }
#endif
