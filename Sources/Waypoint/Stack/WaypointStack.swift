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
    import WaypointOSLog

    /// A navigation stack driven by a `StackRouter`.
    ///
    /// When the root's `NavigationConfiguration` gives no log handler, the stack makes the whole
    /// tree write to the unified log (`OSLogHandler`), at `.notice` by default.
    ///
    /// The stack draws the router's path with one `NavigationStack`, and reports what the user
    /// does by hand (swipe back, the Back button and its long-press menu) back to the router. It
    /// keeps no navigation state of its own. Register a screen for each route type with
    /// ``SwiftUICore/View/destination(_:_:)-(_,(R)->Content)``:
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
    /// Push routes with the router or a ``WaypointLink``, never with `NavigationLink(value:)`:
    /// SwiftUI hands the stack a value it can't read back, so the push is refused and reported as
    /// `rendererMismatch`, in release builds too.
    ///
    /// Screens inside the stack can read its navigator with `@StackNavigation`, dismiss its flow
    /// with `@DismissFlow`, or read the router with `@Environment(StackRouter.self)`. A stack made
    /// with ``init(flow:router:rootName:root:)`` belongs to a flow, which `@FlowNavigation` finds.
    ///
    /// A route whose type the router knows but no screen inside this stack registered, such as
    /// one registered only in another stack, is reported as `missingDestination` and drawn with
    /// the screen chosen by ``SwiftUICore/View/missingDestination(_:)``: by default a debug
    /// screen that names the route and the fix in debug builds, and a blank screen in release.
    ///
    /// The tab bar stays on pushed screens, as the system shows it. To hide it on every screen
    /// pushed above a tab's root, as `hidesBottomBarWhenPushed` does in UIKit, use
    /// ``SwiftUICore/View/tabBarOnPushedScreens(_:)``.
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

        /// The flow this stack belongs to, declared on its router, or `nil` to leave the router's
        /// declaration as it is.
        private let flow: (any NavigationFlow.Type)?

        /// The name of the stack's first screen in the journey, or `nil` to leave the router's
        /// name as it is.
        private let rootName: String?

        /// The stack's first screen.
        private let root: Root

        /// The stack's own router, used when the app passes none. Made once for the stack's
        /// lifetime.
        @State private var ownRouter = StackRouter()

        /// The stack.
        public var body: some View {
            let router = declaredRouter()
            StackHost(router: router, root: root)
                .id(ObjectIdentifier(router))
        }

        /// Creates a stack with its own router.
        ///
        /// - Parameters:
        ///   - rootName: The name of the first screen in the journey box, such as
        ///     `Product list`. Default: `nil`, for the tab's or the flow's name.
        ///   - root: The stack's first screen.
        public init(rootName: String? = nil, @ViewBuilder root: () -> Root) {
            self.init(router: nil, flow: nil, rootName: rootName, root: root)
        }

        /// Creates a stack for a router you own.
        ///
        /// - Parameters:
        ///   - router: The router the stack draws.
        ///   - rootName: The name of the first screen in the journey box, such as
        ///     `Product list`. Default: `nil`, for the router's own name, else its tab's or its
        ///     flow's.
        ///   - root: The stack's first screen.
        public init(_ router: StackRouter, rootName: String? = nil, @ViewBuilder root: () -> Root) {
            self.init(router: router, flow: nil, rootName: rootName, root: root)
        }

        /// Creates a stack that belongs to a flow, so `@FlowNavigation(flow)` finds it.
        ///
        /// ```swift
        /// WaypointStack(flow: ShopFlow.self) {
        ///     ProductListView()
        ///         .destination(ProductRoute.self) { route, navigation in
        ///             ProductView(model: ProductModel(id: route.id, navigation: navigation))
        ///         }
        /// }
        /// ```
        ///
        /// The flow is declared on the router with `declareFlow(_:)`, so
        /// `router.navigator(for:)` reports a `flowMismatch` when asked for another flow.
        ///
        /// - Parameters:
        ///   - flow: The flow whose screens this stack shows.
        ///   - router: A router you own, or `nil` for the stack's own. Default: `nil`.
        ///   - rootName: The name of the first screen in the journey box, such as
        ///     `Product list`. Default: `nil`, for the router's own name, else its tab's or its
        ///     flow's.
        ///   - root: The stack's first screen.
        public init<Flow: NavigationFlow>(
            flow: Flow.Type,
            router: StackRouter? = nil,
            rootName: String? = nil,
            @ViewBuilder root: () -> Root
        ) {
            self.init(router: router, flow: flow, rootName: rootName, root: root)
        }

        /// Creates a stack for `router`, or its own when `nil`, declared for `flow` and with its
        /// root screen named when given.
        init(
            router: StackRouter?,
            flow: (any NavigationFlow.Type)?,
            rootName: String?,
            @ViewBuilder root: () -> Root
        ) {
            self.givenRouter = router
            self.flow = flow
            self.rootName = rootName
            self.root = root()
        }

        /// The router this stack draws, declared for the stack's flow, with its root view named
        /// and its root screen named when given. All are idempotent and observed by nothing, so
        /// they are safe while drawing.
        private func declaredRouter() -> StackRouter {
            let router = givenRouter ?? ownRouter
            router.setRootViewName(ViewTypeName.of(Root.self))
            if let flow {
                router.declareFlow(flow)
            }
            if let rootName {
                router.setRootName(rootName)
            }
            return router
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

        /// The nearest stack of each flow above this one.
        @Environment(\.waypointFlowRouters) private var flowRouters

        /// The stack, with the router in the environment for destinations, the navigation
        /// wrappers and `@Environment(StackRouter.self)`.
        var body: some View {
            NavigationStack(path: path) {
                root
                    .navigationDestination(for: MissingDestinationEntry.self) { entry in
                        MissingDestinationHost(entry: entry, mirror: mirror)
                            .pushedTabBar()
                    }
                    .navigationDestination(for: ChildFlowRoute.self) { marker in
                        PushedFlowRoot(marker: AnyRoute(marker), stack: mirror.router)
                            .pushedTabBar()
                    }
            }
            .environment(\.waypointStackRouter, mirror.router)
            .environment(\.waypointStackMirror, mirror)
            .environment(\.waypointFlowRouters, flowRouters.adding(mirror.router))
            .environment(mirror.router)
            .onChange(of: mirror.router.drawnPath) {
                mirror.routerDidChange()
            }
            .onAppear {
                mirror.stackDidAppear()
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

        /// A host for `router`. When the app gave the tree no log handler, the tree writes to the
        /// unified log from here on.
        init(router: StackRouter, root: Root) {
            DefaultLogging.install(on: router)
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
        /// destination registered for it. A route with no destination in this stack goes in as a
        /// ``MissingDestinationEntry``, which the stack draws with its missing-destination screen.
        var navigationPath: NavigationPath {
            // Read so the stack is drawn again from `shown` after a refused change.
            _ = redrawCount
            return shown.reduce(into: NavigationPath()) { path, route in
                path.append(pathEntry(for: route))
            }
        }

        /// `route` as its own type, or as a missing-destination entry.
        private func pathEntry(for route: AnyRoute) -> any Hashable {
            guard isMissingDestination(route) else {
                return route.base
            }
            return MissingDestinationEntry(route: route)
        }
    }
#endif
