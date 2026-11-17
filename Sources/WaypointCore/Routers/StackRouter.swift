//
//  StackRouter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

/// The owner of one navigation stack.
///
/// Its methods read like what they do, take your own route types, and change the state in one
/// step that the renderer draws:
///
/// ```swift
/// router.push(ProductRoute(id: 42))
/// router.pop()
/// router.popTo(CartRoute())
/// router.popToRoot()
/// ```
///
/// Every navigation method returns a ``NavigationOutcome``, which is discardable, and never
/// throws. Each also records the caller's file and line, so an issue points at the call.
///
/// Conformances:
/// - `NavigationRouter`, so it takes part in the router tree.
/// - `Observable`, so renderers and views redraw when the state changes.
@MainActor
@Observable
public final class StackRouter: NavigationRouter {
    /// The working copy of a stack router during a transaction.
    struct Working {
        /// The state being changed.
        var state: StackState

        /// The presented router being changed.
        var presented: StackRouter?
    }

    /// The current state. Change it only through the methods below.
    public internal(set) var state: StackState

    /// The router of the presented flow, if any.
    public internal(set) var presented: StackRouter?

    /// The flow this router drives.
    @ObservationIgnored public let flowID: FlowID

    /// The route of the stack's root screen, if it has one. `popTo` this route pops to root.
    @ObservationIgnored public let rootRoute: AnyRoute?

    /// The tree this router belongs to.
    @ObservationIgnored let tree: NavigationTreeContext

    /// The router that presented or contains this one.
    @ObservationIgnored private(set) weak var parentNode: (any TreeNode)?

    /// Whether this router is in the tree.
    @ObservationIgnored var isAttached: Bool

    /// The working copy, during a transaction.
    @ObservationIgnored var working: Working?

    /// Presentation defaults set on this router, if any.
    @ObservationIgnored private var ownPresentationDefaults: PresentationDefaults?

    /// What to do when a call fails and passes no fallback, by issue kind.
    ///
    /// Children inherit every kind they don't set themselves. A kind set nowhere uses
    /// ``NavigationFallback/builtIn(for:)``.
    ///
    /// ```swift
    /// router.fallbackPolicy[.routeNotInPath] = .popToRoot
    /// ```
    @ObservationIgnored public var fallbackPolicy = FallbackPolicy()

    /// Creates a root router with an empty path.
    ///
    /// - Parameter flow: The flow's name in logs, events and saved state. Default: `main`.
    public init(flow: FlowID = FlowID("main")) {
        let tree = NavigationTreeContext()
        self.tree = tree
        self.flowID = tree.claimFlowName(flow.name)
        self.rootRoute = nil
        self.state = StackState()
        self.isAttached = true
    }

    /// Creates a root router whose root screen shows `root`, so `popTo(root)` pops to the root.
    public init<R: Route>(root: R, flow: FlowID = FlowID("main")) {
        let tree = NavigationTreeContext()
        self.tree = tree
        self.flowID = tree.claimFlowName(flow.name)
        self.rootRoute = AnyRoute(root)
        self.state = StackState()
        self.isAttached = true
    }

    /// Creates a router for a flow presented by `parent`. It joins the tree when the
    /// transaction that presents it commits.
    init(presentedBy parent: any TreeNode, flow: FlowID, route: AnyRoute) {
        self.tree = parent.tree
        self.flowID = flow
        self.rootRoute = route
        self.parentNode = parent
        self.state = StackState()
        self.isAttached = false
    }

    /// Creates the router of one tab, inside a tab container.
    init(tabOf parent: any TreeNode, flow: FlowID, isAttached: Bool) {
        self.tree = parent.tree
        self.flowID = flow
        self.rootRoute = nil
        self.parentNode = parent
        self.state = StackState()
        self.isAttached = isAttached
    }

    /// The router that presented or contains this one, or `nil` for the root.
    public var parent: (any NavigationRouter)? {
        parentNode
    }

    /// The root router of the whole tree.
    public var root: any NavigationRouter {
        rootNode
    }

    /// The presented flow's router, if any.
    public var children: [any NavigationRouter] {
        childNodes
    }

    /// Whether this router is still in the tree. When it isn't, every call returns `.ignored`.
    public var isActive: Bool {
        isAttached
    }

    /// The route types registered in this tree, for decoding and as destinations.
    public var registry: RouteRegistry {
        tree.registry
    }

    /// The most calls that may be queued while changes are applied, in one main-actor turn.
    /// Shared by the whole tree. Default: 32. Calls past it report `reentrantLoop`.
    public var maxQueuedChanges: Int {
        get {
            tree.maxQueuedChanges
        }
        set {
            tree.maxQueuedChanges = newValue
        }
    }

    /// Default presentation options for this router and its children. Unless set here, they
    /// come from the nearest router above, then ``PresentationDefaults/default``.
    public var presentationDefaults: PresentationDefaults {
        get {
            ownPresentationDefaults ?? parentNode?.presentationDefaults ?? .default
        }
        set {
            ownPresentationDefaults = newValue
        }
    }

    /// Pushes one route.
    @discardableResult
    public func push<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let erased = AnyRoute(route)
        return perform(file: file, line: line, fallback: fallback) { router, store in
            router.pushStep([erased], in: store)
        }
    }

    /// Pops `count` routes.
    ///
    /// A pop on an empty path fails with `emptyPath`, and popping more routes than the path holds
    /// fails with `notEnoughRoutes`. A count of zero or less changes nothing.
    @discardableResult
    public func pop(
        count: Int = 1,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.stackStep(.pop(count: count), in: store)
        }
    }

    /// Pops to the last occurrence of `route`.
    ///
    /// Returns `.alreadyThere` if it is on top. If the route is the stack's root screen, this
    /// pops to root. A route that is not in the path fails with `routeNotInPath`.
    @discardableResult
    public func popTo<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let erased = AnyRoute(route)
        return perform(file: file, line: line, fallback: fallback, route: erased) { router, store in
            router.stackStep(.popTo(erased), in: store)
        }
    }

    /// Empties the path, showing the root screen.
    @discardableResult
    public func popToRoot(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.stackStep(.popToRoot, in: store)
        }
    }

    /// Presents `route` as the root screen of a new child flow, with its own router.
    ///
    /// A flow presents one flow at a time: if one is already presented, this fails with
    /// `alreadyPresenting`. Present again from ``presented`` for a chain of modals.
    @discardableResult
    public func present<R: Route>(
        _ route: R,
        style: PresentationStyle = .sheet,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let erased = AnyRoute(route)
        return perform(file: file, line: line, fallback: fallback) { router, store in
            router.presentStep(erased, style: style, in: store)
        }
    }

    /// Dismisses the flow this router presents, with everything it presents.
    ///
    /// Returns `.alreadyThere` when nothing is presented.
    @discardableResult
    public func dismiss(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.dismissStep(in: store)
        }
    }

    /// Dismisses every flow presented above this router.
    @discardableResult
    public func dismissAll(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.dismissAllStep(in: store)
        }
    }

    /// Asks whoever presented this router's flow to dismiss it.
    ///
    /// Fails with `notPresented` when this flow wasn't presented, such as the root flow.
    @discardableResult
    public func dismissFlow(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.dismissFlowStep(in: store)
        }
    }

    /// The sheet options a presentation uses: its own, or this router's defaults.
    public func sheetOptions(for presentation: Presentation) -> SheetOptions {
        presentation.style.sheetOptions ?? presentationDefaults.sheet
    }

    /// Adds a handler for calls anywhere in this router's tree that failed and could not be
    /// recovered, so the app can show a message or report it. Each failure reaches it once.
    ///
    /// ```swift
    /// rootRouter.onNavigationFailure { failure in
    ///     crashReporter.record(failure.description)
    /// }
    /// ```
    public func onNavigationFailure(_ handler: @escaping @MainActor (NavigationFailure) -> Void) {
        tree.addFailureHandler(handler)
    }

    /// Registers a route type for decoding and as having a destination.
    ///
    /// Renderers and coordinators call this as they register destinations. Once any type is
    /// registered in the tree, pushing or presenting a route type that isn't fails with
    /// `unregisteredRoute`, and never crashes.
    public func register<R: Route>(_ type: R.Type) {
        tree.register(type)
    }

    /// Runs a call on this router as one transaction, with its fallback if it fails.
    func perform(
        file: StaticString,
        line: UInt,
        fallback: NavigationFallback?,
        route: AnyRoute? = nil,
        _ step: @escaping (StackRouter, TransactionStore) -> StepResult
    ) -> NavigationOutcome {
        let context = FallbackContext(explicit: fallback, route: route, file: file, line: line)
        return tree.perform(on: self, file: file, line: line) { [unowned self] store in
            store.resolve(step(self, store), on: self, context)
        }
    }
}
