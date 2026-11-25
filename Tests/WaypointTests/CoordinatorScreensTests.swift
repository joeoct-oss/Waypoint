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

    /// A stack coordinator's `root` and `destinations`, built with the screen builders
    /// (planning #313).
    @Suite("Coordinator screens")
    @MainActor
    struct CoordinatorScreensTests {
        @Test("Destinations register each route with its screen's name")
        func destinationsRegisterEachRouteWithItsScreenName() {
            let coordinator = ScreensShopCoordinator()

            let router = coordinator.router

            #expect(router.registry.isRegistered(ProductRoute.self))
            #expect(router.registry.isRegistered(CartRoute.self))
            #expect(router.tree.viewNames[ProductRoute.routeKey] == "ScreensProductView")
            #expect(router.tree.viewNames[CartRoute.routeKey] == "ScreensCartView")
        }

        @Test("A push from the coordinator needs no register call")
        func pushFromTheCoordinatorNeedsNoRegisterCall() {
            let coordinator = ScreensShopCoordinator()

            let outcome = coordinator.router.push(ProductRoute(id: 1))

            #expect(outcome == .applied)
            #expect(coordinator.router.state.path == [AnyRoute(ProductRoute(id: 1))])
        }

        @Test("A coordinator with only a root has no destinations")
        func coordinatorWithOnlyARootHasNoDestinations() {
            let coordinator = ScreensRootOnlyCoordinator()

            let router = coordinator.router

            #expect(type(of: coordinator.destinations) == EmptyDestinations.self)
            #expect(!router.registry.isRegistered(ProductRoute.self))
            #expect(router.push(ProductRoute(id: 1)).failure?.issue.kind == .unregisteredRoute)
        }

        @Test("Either branch of a root is named by its first screen")
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

        @Test("An optional root is named by its screen")
        func optionalRootIsNamedByItsScreen() {
            let coordinator = ScreensOptionalCoordinator()

            #expect(ViewTypeName.of(type(of: coordinator.root)) == "ScreensCartView")
        }

        #if canImport(UIKit)
            @Test("A view controller screen is named by its controller")
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

        /// The product's name.
        var body: some View {
            Text("Product \(id)")
        }
    }

    /// A cart screen.
    ///
    /// Conformances:
    /// - `View`, so it can be a coordinator's screen.
    private struct ScreensCartView: View {
        /// The cart's title.
        var body: some View {
            Text("Cart")
        }
    }

    /// A shop with a root and two destinations, one of them taking the navigator.
    ///
    /// Conformances:
    /// - `StackCoordinator`, so Waypoint registers its destinations and draws its view.
    private final class ScreensShopCoordinator: StackCoordinator {
        /// The cart.
        var root: some View {
            ScreensCartView()
        }

        /// A product, and the cart again with the navigator.
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
        /// The cart.
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

        /// The product when signed in, else the cart.
        var root: some View {
            if signedIn {
                ScreensProductView(id: 1)
            } else {
                ScreensCartView()
            }
        }

        /// Creates a coordinator whose root shows the product when `signedIn`.
        init(signedIn: Bool) {
            self.signedIn = signedIn
        }
    }

    /// A root built from an `if` with no `else`.
    ///
    /// Conformances:
    /// - `StackCoordinator`, so its root is built with the screen builder.
    private final class ScreensOptionalCoordinator: StackCoordinator {
        /// Whether the root shows the cart.
        let showsCart = true

        /// The cart, when `showsCart`.
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
            /// A view controller.
            var root: some View {
                ScreensViewController()
            }

            /// A view controller for each product.
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
