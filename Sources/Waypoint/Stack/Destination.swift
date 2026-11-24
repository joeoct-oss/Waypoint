//
//  Destination.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    extension View {
        /// Shows `route`'s screen when a route of type `R` is pushed onto the enclosing
        /// ``WaypointStack``.
        ///
        /// SwiftUI gets one `navigationDestination(for:)` per route type, so screens are never
        /// wrapped in `AnyView`. The route type is also registered with the stack's router, which
        /// lets the router save and restore it, and refuse route types that have no screen.
        ///
        /// ```swift
        /// ProductListView(onSelect: { router.push(ProductRoute(id: $0)) })
        ///     .destination(ProductRoute.self) { route in
        ///         ProductView(id: route.id)
        ///     }
        /// ```
        public func destination<R: Route, Content: View>(
            _ type: R.Type,
            @ViewBuilder _ content: @escaping (R) -> Content
        ) -> some View {
            let screen: (R, StackNavigator) -> Content = { route, _ in
                content(route)
            }
            return modifier(DestinationModifier(content: screen))
        }

        /// Shows `route`'s screen, and hands it the stack's navigator for its view model.
        ///
        /// The blessed way to give a view model its navigation: the model keeps the navigator,
        /// imports only `WaypointCore`, and is tested with a real router.
        ///
        /// ```swift
        /// .destination(ProductRoute.self) { route, navigation in
        ///     ProductView(model: ProductModel(id: route.id, navigation: navigation))
        /// }
        /// ```
        ///
        /// A model that only takes its flow's routes asks for
        /// `navigation.scoped(to: ShopFlow.self)`.
        public func destination<R: Route, Content: View>(
            _ type: R.Type,
            @ViewBuilder _ content: @escaping (R, StackNavigator) -> Content
        ) -> some View {
            modifier(DestinationModifier(content: content))
        }
    }

    /// Registers one route type's screen with SwiftUI and with the stack's router.
    ///
    /// Conformances:
    /// - `ViewModifier`, so ``SwiftUICore/View/destination(_:_:)-(_,(R)->Content)`` can apply it.
    /// - `R: Route`: the route type this registers.
    /// - `Destination: View`: the screen it shows.
    struct DestinationModifier<R: Route, Destination: View>: ViewModifier {
        /// Builds the screen for one route, with the stack's navigator.
        let content: (R, StackNavigator) -> Destination

        /// The router of the enclosing stack, if any.
        @Environment(\.waypointStackRouter) private var router

        /// The mirror of the enclosing stack, if any, which learns the stack's destinations.
        @Environment(\.waypointStackMirror) private var mirror

        /// The nearest stack of each flow, as this screen sees them.
        @Environment(\.waypointFlowRouters) private var flowRouters

        /// The view, with the route type's destination.
        func body(content view: Content) -> some View {
            // Registering is idempotent and observed by nothing, so it is safe while drawing,
            // and it happens before the first push the screen can make.
            router?.register(R.self)
            router?.registerViewName(ViewTypeName.of(Destination.self), for: R.self)
            mirror?.registerDestination(R.self)
            let stackRouter = router
            let flows = flowRouters
            return view.navigationDestination(for: R.self) { route in
                let navigator = NavigatorLookup.destination(stackRouter, route: route, report: NavigationIssueLog.report)
                content(route, navigator)
                    .stackRouterEnvironment(stackRouter, flows: flows)
                    .pushedTabBar()
            }
        }
    }

    extension View {
        /// The view, seeing `router` as its stack's router and `flows` as the flows above it, as
        /// the screen that declared its destination does. A pushed child flow's screens are drawn
        /// on its parent's stack, and see the child's router, never the parent's.
        @ViewBuilder
        fileprivate func stackRouterEnvironment(_ router: StackRouter?, flows: FlowRouters) -> some View {
            if let router {
                environment(\.waypointStackRouter, router)
                    .environment(\.waypointFlowRouters, flows)
                    .environment(router)
            } else {
                self
            }
        }
    }

    extension EnvironmentValues {
        /// The router of the nearest ``WaypointStack``, or `nil` outside one.
        @Entry var waypointStackRouter: StackRouter?

        /// The mirror of the nearest ``WaypointStack``, or `nil` outside one. Destinations register
        /// with it, so the stack knows which route types it can draw.
        @Entry var waypointStackMirror: StackMirror?

        /// The screen the app chose for a route with no destination in its stack, or `nil` for
        /// the default.
        @Entry var waypointMissingDestination: MissingDestinationScreen?

        /// The nearest stack of each declared flow, for `@FlowNavigation`.
        @Entry var waypointFlowRouters = FlowRouters()
    }
#endif
