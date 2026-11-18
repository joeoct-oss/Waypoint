//
//  MissingDestination.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// A route a stack shows, but no screen inside that stack registered a destination for.
    ///
    /// The tree knows the route's type, because another stack registered it or the root's
    /// `NavigationConfiguration` lists it in its registry, so the push went ahead. The stack
    /// reports `missingDestination` once for the type and draws the screen chosen with
    /// ``SwiftUICore/View/missingDestination(_:)`` in its place.
    public struct MissingDestination {
        /// The route with no destination in its stack.
        public let route: AnyRoute

        /// The issue the stack reported for the route's type, with the fix.
        public let issue: NavigationIssue

        /// The name of the route's type, such as `ProductRoute`. Never a field value.
        public var routeTypeName: String {
            route.routeKey.typeName
        }

        /// A missing destination, such as one to preview your own screen with.
        public init(route: AnyRoute, issue: NavigationIssue) {
            self.route = route
            self.issue = issue
        }
    }

    extension View {
        /// Chooses what the stacks inside this view show for a route with no destination of their
        /// own.
        ///
        /// By default, debug builds show a screen that names the route type and the fix, and
        /// release builds show a blank screen. Both report `missingDestination` once per route
        /// type, and the screen keeps the system Back button, so the user can go back. Pass your
        /// own screen to show the same thing in every build:
        ///
        /// ```swift
        /// WaypointStack(router) {
        ///     ShopView()
        /// }
        /// .missingDestination { missing in
        ///     UnavailableView(onBack: { router.pop() })
        /// }
        /// ```
        ///
        /// - Parameter content: The screen for one missing destination.
        public func missingDestination<Content: View>(
            @ViewBuilder _ content: @escaping (MissingDestination) -> Content
        ) -> some View {
            let screen = MissingDestinationScreen { missing in
                AnyView(content(missing))
            }
            return environment(\.waypointMissingDestination, screen)
        }
    }

    /// The screen an app chose for a route with no destination in its stack.
    ///
    /// Conformances:
    /// - `@MainActor` class, so it can sit in SwiftUI's `Sendable` environment store while it
    ///   keeps the app's closure, which runs only while drawing.
    @MainActor
    final class MissingDestinationScreen {
        /// Makes the screen. `AnyView` because the environment can't keep a generic view; it is
        /// used only for this one screen, never for destinations.
        let make: (MissingDestination) -> AnyView

        /// A screen made by `make`.
        init(make: @escaping (MissingDestination) -> AnyView) {
            self.make = make
        }
    }

    /// The path entry a stack uses for a route with no destination in it, so SwiftUI draws the
    /// missing-destination screen instead of an empty one.
    ///
    /// Conformances:
    /// - `Hashable`, so it can go in a `NavigationPath`.
    struct MissingDestinationEntry: Hashable {
        /// The route with no destination.
        let route: AnyRoute
    }

    /// Draws the app's missing-destination screen, or the default one.
    struct MissingDestinationHost: View {
        /// The path entry being drawn.
        let entry: MissingDestinationEntry

        /// The stack's mirror, which keeps the reported issue.
        let mirror: StackMirror

        /// The screen the app chose, or `nil` for the default.
        @Environment(\.waypointMissingDestination) private var screen

        /// The chosen screen, or the default one.
        var body: some View {
            if let issue = mirror.missingDestinations[entry.route.routeKey] {
                makeScreen(for: MissingDestination(route: entry.route, issue: issue))
            }
        }

        /// The app's screen for `missing`, or the default one.
        @ViewBuilder
        private func makeScreen(for missing: MissingDestination) -> some View {
            if let screen {
                screen.make(missing)
            } else {
                DefaultMissingDestinationView(missing: missing)
            }
        }
    }

    /// The default missing-destination screen: the debug screen in debug builds, and a blank
    /// screen in release builds, where nothing about the app's code is shown to its users.
    struct DefaultMissingDestinationView: View {
        /// The route with no destination.
        let missing: MissingDestination

        /// The screen for this build.
        var body: some View {
            #if DEBUG
                MissingDestinationDebugView(missing: missing)
            #else
                Color.clear
            #endif
        }
    }
#endif
