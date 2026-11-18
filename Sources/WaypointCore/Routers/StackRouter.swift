//
//  StackRouter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
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
    /// What a stack router shows: its state and the router of the flow it presents.
    struct Snapshot {
        /// The stack's state.
        let state: StackState

        /// The router of the presented flow, if any.
        let presented: StackRouter?

        /// The same snapshot with another state.
        func withState(_ state: StackState) -> Snapshot {
            Snapshot(state: state, presented: presented)
        }

        /// The same snapshot presenting another flow, or none.
        func presenting(_ presentation: Presentation?, by router: StackRouter?) -> Snapshot {
            Snapshot(state: state.withPresentation(presentation), presented: router)
        }
    }

    /// The flow this router drives.
    @ObservationIgnored public let flowID: FlowID

    /// The route of the stack's root screen, if it has one. `popTo` this route pops to root.
    @ObservationIgnored public let rootRoute: AnyRoute?

    /// The tree this router belongs to.
    @ObservationIgnored let tree: NavigationTreeContext

    /// The router that presented or contains this one.
    @ObservationIgnored weak let parentNode: (any TreeNode)?

    /// The committed state and presented router, which renderers observe.
    ///
    /// `var` because it is the router's current value. Only `commitWorkingCopy()` replaces it.
    private var committed: Snapshot

    /// The copy a transaction changes, or `nil` between transactions.
    ///
    /// `var` because a transaction changes it step by step. Only the working-copy functions in
    /// this file change it.
    @ObservationIgnored private var working: Snapshot?

    /// Whether this router is in the tree.
    ///
    /// `var` because a router joins the tree when the transaction that creates it commits, and
    /// leaves when its flow is dismissed. Only `markAttached()` and `markDetached()` change it.
    @ObservationIgnored private(set) var isAttached: Bool

    /// Presentation defaults and fallbacks set on this router.
    ///
    /// `var` because an app may set them after creating the router. Only
    /// ``setPresentationDefaults(_:)`` and ``setFallback(_:for:file:line:)`` change it.
    @ObservationIgnored private var settings = RouterSettings()

    /// The current state. Change it through the navigation methods below.
    public var state: StackState {
        committed.state
    }

    /// The router of the presented flow, if any.
    public var presented: StackRouter? {
        committed.presented
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

    /// The settings of the whole tree, given once to the root router. Every router in the tree
    /// reads the same value, and none can change it. The registry holds every route type
    /// registered since.
    public var configuration: NavigationConfiguration {
        tree.configuration
    }

    /// Default presentation options for this router and its children. Unless set here, they
    /// come from the nearest router above, then ``PresentationDefaults/default``.
    public var presentationDefaults: PresentationDefaults {
        settings.presentationDefaults ?? parentNode?.presentationDefaults ?? .default
    }

    /// What to do when a call fails and passes no fallback, by issue kind.
    ///
    /// Children inherit every kind they don't set themselves. A kind set nowhere uses
    /// ``NavigationFallback/builtIn(for:)``. Set an entry with ``setFallback(_:for:file:line:)``.
    public var fallbackPolicy: FallbackPolicy {
        settings.fallbackPolicy
    }

    /// The working copy during a transaction, or the committed snapshot.
    var current: Snapshot {
        working ?? committed
    }

    /// Creates a root router with an empty path.
    ///
    /// - Parameters:
    ///   - flow: The flow's name in logs, events and saved state. Default: `main`.
    ///   - configuration: The settings of the whole tree. Default:
    ///     ``NavigationConfiguration/default``.
    ///   - file: The file that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    ///   - line: The line that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    public convenience init(
        flow: FlowID = FlowID("main"),
        configuration: NavigationConfiguration = .default,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        self.init(rootRoute: nil, flow: flow, configuration: configuration, file: file, line: line)
    }

    /// Creates a root router whose root screen shows `root`, so `popTo(root)` pops to the root.
    ///
    /// - Parameters:
    ///   - root: The route of the root screen.
    ///   - flow: The flow's name in logs, events and saved state. Default: `main`.
    ///   - configuration: The settings of the whole tree. Default:
    ///     ``NavigationConfiguration/default``.
    ///   - file: The file that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    ///   - line: The line that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    public convenience init<R: Route>(
        root: R,
        flow: FlowID = FlowID("main"),
        configuration: NavigationConfiguration = .default,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        self.init(rootRoute: AnyRoute(root), flow: flow, configuration: configuration, file: file, line: line)
    }

    /// Creates a root router and its tree, and reports a setting the tree could not use.
    private init(
        rootRoute: AnyRoute?,
        flow: FlowID,
        configuration: NavigationConfiguration,
        file: StaticString,
        line: UInt
    ) {
        let tree = NavigationTreeContext(configuration: configuration)
        self.tree = tree
        self.flowID = tree.claimFlowName(flow.name)
        self.rootRoute = rootRoute
        self.parentNode = nil
        self.committed = Snapshot(state: StackState(), presented: nil)
        self.isAttached = true
        if let problem = tree.configurationProblem {
            reportInvalidSetting(problem, file: file, line: line)
        }
    }

    /// Creates a router for a flow presented by `parent`. It joins the tree when the
    /// transaction that presents it commits.
    init(presentedBy parent: any TreeNode, flow: FlowID, route: AnyRoute) {
        self.tree = parent.tree
        self.flowID = flow
        self.rootRoute = route
        self.parentNode = parent
        self.committed = Snapshot(state: StackState(), presented: nil)
        self.isAttached = false
    }

    /// Creates the router of one tab, inside a tab container.
    init(tabOf parent: any TreeNode, flow: FlowID, isAttached: Bool) {
        self.tree = parent.tree
        self.flowID = flow
        self.rootRoute = nil
        self.parentNode = parent
        self.committed = Snapshot(state: StackState(), presented: nil)
        self.isAttached = isAttached
    }

    /// Pushes one route.
    @discardableResult
    public func push<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let routes = [AnyRoute(route)]
        return perform(file: file, line: line, fallback: fallback) { router, store in
            router.pushStep(routes, in: store)
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
        let request = PresentationRequest(route: erased, style: style)
        return perform(file: file, line: line, fallback: fallback, presentation: request) { router, store in
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

    /// The whole tree this router is in, one flow per line, for printing while debugging.
    ///
    /// ```text
    /// tabs       home · [shop] · profile
    /// ├ home     first screen
    /// ├ shop     Product list (…) › Product (id: 42, …)
    /// │ └ sheet checkout  Checkout (…)
    /// └ profile  first screen
    /// ```
    ///
    /// Route fields are hidden unless `revealingPrivateValues` is `true` or a route lists them
    /// in `publicLogFields`. Symbols follow the tree's ``LogConfiguration/usesSymbols``.
    public func debugTree(revealingPrivateValues: Bool = false) -> String {
        let naming = RouteNaming(
            format: .readable,
            revealsPrivateValues: revealingPrivateValues,
            usesSymbols: tree.logging.usesSymbols
        )
        return rootNode.readableTree(naming).rendered
    }

    /// Sets the default presentation options for this router and its children.
    ///
    /// ```swift
    /// let detents: [SheetDetent] = [.medium, .large]
    /// let sheet = SheetOptions(detents: detents)
    /// router.setPresentationDefaults(PresentationDefaults(sheet: sheet))
    /// ```
    public func setPresentationDefaults(_ defaults: PresentationDefaults) {
        settings = settings.withPresentationDefaults(defaults)
    }

    /// Sets what to do when a call of this kind fails and passes no fallback, for this flow and
    /// its children. `nil` inherits the parent's entry again.
    ///
    /// ```swift
    /// router.setFallback(.popToRoot, for: .routeNotInPath)
    /// ```
    ///
    /// `.push` only applies to `routeNotInPath`. Set for another kind, it reports
    /// `invalidSetting` and the fallback stays as it was.
    public func setFallback(
        _ fallback: NavigationFallback?,
        for kind: NavigationIssue.Kind,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        if let problem = fallbackSettingProblem(fallback, for: kind) {
            reportInvalidSetting(problem, file: file, line: line)
            return
        }
        settings = settings.withFallback(fallback, for: kind)
    }

    /// The sheet options a presentation uses: its own, or this router's defaults.
    public func sheetOptions(for presentation: Presentation) -> SheetOptions {
        presentation.style.sheetOptions ?? presentationDefaults.sheet
    }

    /// Registers a route type for decoding and as having a destination.
    ///
    /// Renderers and coordinators call this as they register destinations. Unless the root's
    /// registry is ``RouteRegistry/permissive``, pushing or presenting a route type that isn't
    /// registered fails with `unregisteredRoute`, even before anything is registered, and never
    /// crashes.
    public func register<R: Route>(_ type: R.Type) {
        tree.register(type)
    }

    /// Runs a call on this router as one transaction, with its fallback if it fails.
    func perform(
        file: StaticString,
        line: UInt,
        fallback: NavigationFallback?,
        route: AnyRoute? = nil,
        presentation: PresentationRequest? = nil,
        _ step: @escaping (StackRouter, TransactionStore) -> StepResult
    ) -> NavigationOutcome {
        let context = FallbackContext(
            explicit: fallback,
            route: route,
            presentation: presentation,
            file: file,
            line: line
        )
        return tree.perform(on: self, file: file, line: line) { [unowned self] store in
            store.resolve(step(self, store), on: self, context)
        }
    }
}

/// Conformances:
/// - `TransactionParticipant`, so a transaction can change it on a working copy.
extension StackRouter: TransactionParticipant {
    /// Copies the committed snapshot.
    func beginWorkingCopy() {
        working = committed
    }

    /// Changes the working copy. Does nothing outside a transaction.
    func updateWorkingCopy(_ change: (Snapshot) -> Snapshot) {
        guard let working else {
            return
        }
        self.working = change(working)
    }

    /// Writes the working copy once, when it differs, and swaps the presented router if it
    /// changed.
    func commitWorkingCopy() {
        guard let next = working else {
            return
        }
        working = nil
        let previous = committed
        guard next.state != previous.state || next.presented !== previous.presented else {
            return
        }
        committed = next
        guard next.presented !== previous.presented else {
            return
        }
        previous.presented?.detachSubtree()
        next.presented?.markAttached()
    }

    /// Drops the working copy, and frees the name of a presented router that never joined.
    func discardWorkingCopy() {
        if let created = working?.presented, created !== committed.presented {
            tree.releaseFlowName(created.flowID)
        }
        working = nil
    }

    /// Marks this router as in the tree, when the transaction that created it commits.
    func markAttached() {
        isAttached = true
    }

    /// Marks this router as gone from the tree. Its calls return `.ignored` from now on.
    func markDetached() {
        isAttached = false
    }
}
