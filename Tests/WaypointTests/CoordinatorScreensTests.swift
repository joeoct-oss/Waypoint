//
//  CoordinatorScreensTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import Testing
    import WaypointTestSupport

    #if canImport(UIKit)
        import UIKit
    #endif

    @testable import Waypoint
    @testable import WaypointCore

    /// A stack coordinator's `root` and `destinations`, built with the screen builders (#59).
    @Suite("Coordinator screens")
    @MainActor
    struct CoordinatorScreensTests {
        @Test
        func destinationsRegisterEachRouteWithItsScreenName() {
            let coordinator = ScreensShopCoordinator()

            let router = coordinator.router

            #expect(router.registry.isRegistered(ProductRoute.self))
            #expect(router.registry.isRegistered(CartRoute.self))
            #expect(router.tree.viewNames[ProductRoute.routeKey] == "ScreensProductView")
            #expect(router.tree.viewNames[CartRoute.routeKey] == "ScreensCartView")
        }

        @Test
        func pushFromTheCoordinatorNeedsNoRegisterCall() {
            let coordinator = ScreensShopCoordinator()

            let outcome = coordinator.router.push(ProductRoute(id: 1))

            #expect(outcome == .applied)
            #expect(coordinator.router.state.path == [AnyRoute(ProductRoute(id: 1))])
        }

        @Test
        func coordinatorWithOnlyARootHasNoDestinations() {
            let coordinator = ScreensRootOnlyCoordinator()

            let router = coordinator.router

            #expect(type(of: coordinator.destinations) == EmptyDestinations.self)
            #expect(!router.registry.isRegistered(ProductRoute.self))
            #expect(router.push(ProductRoute(id: 1)).failure?.issue.kind == .unregisteredRoute)
        }

        @Test
        func eitherBranchOfARootIsNamedByItsFirstScreen() {
            let signedIn = ScreensBranchCoordinator(signedIn: true)
            let signedOut = ScreensBranchCoordinator(signedIn: false)

            let signedInName = ViewTypeName.of(type(of: signedIn.root))
            let signedOutName = ViewTypeName.of(type(of: signedOut.root))

            #expect(signedInName == "ScreensProductView")
            #expect(signedOutName == "ScreensProductView")
            typealias Branches = EitherScreen<ScreensProductView, ScreensCartView>
            #expect((signedOut.root as? Branches)?.isSecond == true)
            #expect((signedIn.root as? Branches)?.isSecond == false)
        }

        @Test
        func optionalRootIsNamedByItsScreen() {
            let coordinator = ScreensOptionalCoordinator()

            #expect(ViewTypeName.of(type(of: coordinator.root)) == "ScreensCartView")
        }

        #if canImport(UIKit)
            @Test
            func viewControllerScreenIsNamedByItsController() {
                let coordinator = ScreensControllerCoordinator()

                #expect(ViewTypeName.of(type(of: coordinator.root)) == "ScreensViewController")
                #expect(coordinator.router.tree.viewNames[ProductRoute.routeKey] == "ScreensViewController")
            }
        #endif
    }

    /// A product screen.
    ///
    /// Conformances:
    /// - `View`, so it can be a coordinator's screen.
    private struct ScreensProductView: View {
        /// The product shown.
        let id: Int

        var body: some View {
            Text("Product \(id)")
        }
    }

    /// A cart screen.
    ///
    /// Conformances:
    /// - `View`, so it can be a coordinator's screen.
    private struct ScreensCartView: View {
        var body: some View {
            Text("Cart")
        }
    }

    /// A shop with a root and two destinations, one of them taking the navigator.
    ///
    /// Conformances:
    /// - `StackCoordinator`, so Waypoint registers its destinations and draws its view.
    private final class ScreensShopCoordinator: StackCoordinator {
        var root: some View {
            ScreensCartView()
        }

        var destinations: some Destinations {
            Destination(ProductRoute.self) { route in
                ScreensProductView(id: route.id)
            }
            Destination(CartRoute.self) { _, _ in
                ScreensCartView()
            }
        }
    }

    /// A flow of one screen, which takes the default destinations.
    ///
    /// Conformances:
    /// - `StackCoordinator`, so Waypoint fills in its destinations.
    private final class ScreensRootOnlyCoordinator: StackCoordinator {
        var root: some View {
            ScreensCartView()
        }
    }

    /// A root that picks one of two screens.
    ///
    /// Conformances:
    /// - `StackCoordinator`, so its root is built with the screen builder.
    private final class ScreensBranchCoordinator: StackCoordinator {
        /// Picks the root's branch.
        let signedIn: Bool

        /// Creates a coordinator whose root shows the product when `signedIn`.
        init(signedIn: Bool) {
            self.signedIn = signedIn
        }

        var root: some View {
            if signedIn {
                ScreensProductView(id: 1)
            } else {
                ScreensCartView()
            }
        }
    }

    /// A root built from an `if` with no `else`.
    ///
    /// Conformances:
    /// - `StackCoordinator`, so its root is built with the screen builder.
    private final class ScreensOptionalCoordinator: StackCoordinator {
        /// Whether the root shows the cart.
        let showsCart = true

        var root: some View {
            if showsCart {
                ScreensCartView()
            }
        }
    }

    #if canImport(UIKit)
        /// A UIKit screen.
        private final class ScreensViewController: UIViewController { }

        /// A root and a destination that are view controllers.
        ///
        /// Conformances:
        /// - `StackCoordinator`, so its view controllers are wrapped as screens.
        private final class ScreensControllerCoordinator: StackCoordinator {
            var root: some View {
                ScreensViewController()
            }

            var destinations: some Destinations {
                Destination(ProductRoute.self) { _ in
                    ScreensViewController()
                }
            }
        }
    #endif

    extension EitherScreen {
        /// Whether the second branch was built.
        var isSecond: Bool {
            if case .second = self {
                return true
            }
            return false
        }
    }
#endif
