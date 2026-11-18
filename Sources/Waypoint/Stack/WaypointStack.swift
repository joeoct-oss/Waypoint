//
//  WaypointStack.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// A navigation stack driven by a `StackRouter`.
    ///
    /// The stack draws the router's path with one `NavigationStack`, and reports what the user
    /// does by hand (swipe back, the Back button and its long-press menu) back to the router. It
    /// keeps no navigation state of its own. Register a screen for each route type with
    /// ``SwiftUICore/View/destination(_:_:)``:
    ///
    /// ```swift
    /// WaypointStack(router) {
    ///     ProductListView(onSelect: { router.push(ProductRoute(id: $0)) })
    ///         .destination(ProductRoute.self) { route in
    ///             ProductView(id: route.id)
    ///         }
    /// }
    /// ```
    ///
    /// Push routes with the router, never with `NavigationLink(value:)`: SwiftUI hands the stack
    /// a value it can't read back, so the push is refused and reported as `rendererMismatch`.
    ///
    /// A stack keeps drawing the router it was first given. Pass another router and the stack
    /// starts again from that router's path.
    ///
    /// Conformances:
    /// - `Root: View`: the stack's first screen.
    public struct WaypointStack<Root: View>: View {
        /// Whether this system needs changes that land mid-transition to be held. iOS 17 drops
        /// them otherwise; later systems apply them.
        static var holdsTransitions: Bool {
            if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) {
                return false
            }
            return true
        }

        /// The router the app passed, or `nil` when the stack owns its router.
        private let givenRouter: StackRouter?

        /// The stack's first screen.
        private let root: Root

        /// The stack's own router, used when the app passes none. Made once for the stack's
        /// lifetime.
        @State private var ownRouter = StackRouter()

        /// The stack.
        public var body: some View {
            let router = givenRouter ?? ownRouter
            StackHost(router: router, root: root)
                .id(ObjectIdentifier(router))
        }

        /// Creates a stack with its own router.
        public init(@ViewBuilder root: () -> Root) {
            self.givenRouter = nil
            self.root = root()
        }

        /// Creates a stack for a router you own.
        public init(_ router: StackRouter, @ViewBuilder root: () -> Root) {
            self.givenRouter = router
            self.root = root()
        }
    }

    /// Draws one router with a `NavigationStack`, through a ``StackMirror``.
    ///
    /// Conformances:
    /// - `Root: View`: the stack's first screen.
    struct StackHost<Root: View>: View {
        /// The stack's first screen.
        let root: Root

        /// What the stack shows, kept in step with the router. Made once for this router.
        @State private var mirror: StackMirror

        /// The stack, with the router in the environment for destinations.
        var body: some View {
            NavigationStack(path: path) {
                root
            }
            .environment(\.waypointStackRouter, mirror.router)
            .onChange(of: mirror.router.state.path) {
                mirror.routerDidChange()
            }
        }

        /// The mirror's routes as a `NavigationPath`. The setter only hears a different count:
        /// fewer routes after a user pop, more after a `NavigationLink(value:)`.
        private var path: Binding<NavigationPath> {
            Binding(
                get: { mirror.navigationPath },
                set: { mirror.screenDidShow(count: $0.count) }
            )
        }

        /// A host for `router`.
        init(router: StackRouter, root: Root) {
            self.root = root
            let mirror = StackMirror(
                router: router,
                holdsTransitions: WaypointStack<Root>.holdsTransitions,
                clock: SystemTransitionClock()
            )
            self._mirror = State(initialValue: mirror)
        }
    }

    extension StackMirror {
        /// The routes on screen as a `NavigationPath`, each as its own type, so SwiftUI finds the
        /// destination registered for it.
        var navigationPath: NavigationPath {
            // Read so the stack is drawn again from `shown` after a refused change.
            _ = redrawCount
            return shown.reduce(into: NavigationPath()) { path, route in
                path.append(route.base)
            }
        }
    }
#endif
