//
//  Destinations.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// The screens of a coordinator's stack, by route type, built with ``DestinationsBuilder``
    /// from ``Destination`` entries.
    ///
    /// ```swift
    /// var destinations: some Destinations {
    ///     Destination(ProductRoute.self) { route in
    ///         ProductView(id: route.id)
    ///     }
    ///     Destination(CartRoute.self) { _, navigation in
    ///         CartView(model: CartModel(navigation: navigation))
    ///     }
    /// }
    /// ```
    ///
    /// Conformances:
    /// - `ViewModifier`, so the stack's root screen gets one `navigationDestination(for:)` for
    ///   each route type, with no `AnyView`.
    @MainActor
    public protocol Destinations: ViewModifier {
        /// Registers each route type with `router`, with the name of its screen for the journey,
        /// before the stack is drawn, so a push from the coordinator's `init` is never refused.
        func registerRoutes(on router: StackRouter)
    }

    /// One route type's screen in a coordinator's ``Destinations``.
    ///
    /// Conformances:
    /// - `Destinations`, so it can be listed in a coordinator's destinations.
    /// - `R: Route`: the route type it shows.
    /// - `Screen: View`: the route's screen, a SwiftUI view or a view controller's
    ///   ``ControllerScreen``.
    public struct Destination<R: Route, Screen: View>: Destinations {
        /// Builds the screen for one route, with the stack's navigator.
        private let screen: (R, StackNavigator) -> Screen

        /// Shows `content` for each route of type `type`.
        ///
        /// ```swift
        /// Destination(ProductRoute.self) { route in
        ///     ProductView(id: route.id)
        /// }
        /// ```
        public init(_ type: R.Type, @ScreenBuilder _ screen: @escaping (R) -> Screen) {
            self.screen = { route, _ in
                screen(route)
            }
        }

        /// Shows `content` for each route of type `type`, and hands it the stack's navigator for
        /// its view model.
        ///
        /// ```swift
        /// Destination(ProductRoute.self) { route, navigation in
        ///     ProductView(model: ProductModel(id: route.id, navigation: navigation))
        /// }
        /// ```
        public init(_ type: R.Type, @ScreenBuilder _ screen: @escaping (R, StackNavigator) -> Screen) {
            self.screen = screen
        }

        /// Registers `R`, and the name of its screen for the journey.
        public func registerRoutes(on router: StackRouter) {
            router.register(R.self)
            router.registerViewName(ViewTypeName.of(Screen.self), for: R.self)
        }

        /// The view, with `R`'s destination.
        public func body(content: Content) -> some View {
            content.modifier(DestinationModifier(content: screen))
        }
    }

    /// No screens: a coordinator whose stack shows only its root screen.
    ///
    /// Conformances:
    /// - `Destinations`, so it can stand for a coordinator's destinations.
    public struct EmptyDestinations: Destinations {
        /// No screens.
        public init() { }

        /// Registers nothing.
        public func registerRoutes(on router: StackRouter) { }

        /// The view as it is.
        public func body(content: Content) -> some View {
            content
        }
    }

    /// Two groups of screens, listed one after the other in a ``DestinationsBuilder``.
    ///
    /// Conformances:
    /// - `Destinations`, so both groups stand as one.
    /// - `First: Destinations` and `Second: Destinations`: the two groups.
    public struct DestinationPair<First: Destinations, Second: Destinations>: Destinations {
        /// The group listed first.
        private let first: First

        /// The group listed second.
        private let second: Second

        /// Both groups.
        init(_ first: First, _ second: Second) {
            self.first = first
            self.second = second
        }

        /// Registers both groups' route types.
        public func registerRoutes(on router: StackRouter) {
            first.registerRoutes(on: router)
            second.registerRoutes(on: router)
        }

        /// The view, with both groups' destinations.
        public func body(content: Content) -> some View {
            content
                .modifier(first)
                .modifier(second)
        }
    }

    /// Builds a coordinator's ``Destinations`` from ``Destination`` entries listed one per line.
    @MainActor
    @resultBuilder
    public enum DestinationsBuilder {
        /// No entries.
        public static func buildBlock() -> EmptyDestinations {
            EmptyDestinations()
        }

        /// The first entry.
        public static func buildPartialBlock<First: Destinations>(first: First) -> First {
            first
        }

        /// The entries so far, then the next one.
        public static func buildPartialBlock<Accumulated: Destinations, Next: Destinations>(
            accumulated: Accumulated,
            next: Next
        ) -> DestinationPair<Accumulated, Next> {
            DestinationPair(accumulated, next)
        }
    }
#endif
