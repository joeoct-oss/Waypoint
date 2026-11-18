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
            modifier(DestinationModifier(content: content))
        }
    }

    /// Registers one route type's screen with SwiftUI and with the stack's router.
    ///
    /// Conformances:
    /// - `ViewModifier`, so ``SwiftUICore/View/destination(_:_:)`` can apply it.
    /// - `R: Route`: the route type this registers.
    /// - `Destination: View`: the screen it shows.
    struct DestinationModifier<R: Route, Destination: View>: ViewModifier {
        /// Builds the screen for one route.
        let content: (R) -> Destination

        /// The router of the enclosing stack, if any.
        @Environment(\.waypointStackRouter) private var router

        /// The view, with the route type's destination.
        func body(content view: Content) -> some View {
            // Registering is idempotent and observed by nothing, so it is safe while drawing,
            // and it happens before the first push the screen can make.
            router?.register(R.self)
            return view.navigationDestination(for: R.self) { route in
                content(route)
            }
        }
    }

    extension EnvironmentValues {
        /// The router of the nearest ``WaypointStack``, or `nil` outside one.
        @Entry var waypointStackRouter: StackRouter?
    }
#endif
