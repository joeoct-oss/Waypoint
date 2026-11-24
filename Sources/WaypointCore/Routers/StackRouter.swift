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

        /// The router of the child flow pushed on top of this stack, if any. Its marker is the
        /// last route of the path.
        let pushed: StackRouter?

        /// A snapshot of `state`, presenting `presented` and with `pushed` on top.
        init(state: StackState, presented: StackRouter?, pushed: StackRouter? = nil) {
            self.state = state
            self.presented = presented
            self.pushed = pushed
        }

        /// The same snapshot with another state.
        func withState(_ state: StackState) -> Snapshot {
            Snapshot(state: state, presented: presented, pushed: pushed)
        }

        /// The same snapshot presenting another flow, or none.
        func presenting(_ presentation: Presentation?, by router: StackRouter?) -> Snapshot {
            Snapshot(state: state.withPresentation(presentation), presented: router, pushed: pushed)
        }

        /// The same snapshot with another state and another pushed child flow, or none.
        func pushing(_ router: StackRouter?, state: StackState) -> Snapshot {
            Snapshot(state: state, presented: presented, pushed: router)
        }
    }

    /// The flow this router drives.
    ///
    /// `var` because a router that joins another tree takes a name that is free there, such as
    /// its tab's. Only the `join` functions and `moveSubtree(into:from:)` change it.
    @ObservationIgnored public private(set) var flowID: FlowID

    /// The route of the stack's root screen, if it has one. `popTo` this route pops to root.
    @ObservationIgnored public let rootRoute: AnyRoute?

    /// The tree this router belongs to.
    ///
    /// `var` because a router made on its own joins another tree once, such as a tab child's
    /// router becoming the tab's stack. Only `moveSubtree(into:from:)` changes it.
    @ObservationIgnored private(set) var tree: NavigationTreeContext

    /// The router that presented or contains this one.
    ///
    /// `var` because a router made on its own gets a parent when it joins another tree. Only the
    /// `join` functions and `undoJoin()` change it.
    @ObservationIgnored private(set) weak var parentNode: (any TreeNode)?

    /// The router every call goes to once a tab container took this router's place with another,
    /// or `nil`. Held weakly: the target keeps this router, so a navigator of its root screen
    /// keeps working as long as the target does.
    ///
    /// `var` because a router starts forwarding when it is replaced. Only `forward(to:)` changes
    /// it.
    @ObservationIgnored private(set) weak var forwardTarget: StackRouter?

    /// The routers that forward to this one, kept so their navigators keep working.
    ///
    /// `var` because routers start forwarding to this one as they are replaced. Only
    /// `forward(to:)` changes it.
    @ObservationIgnored private(set) var forwarders: [StackRouter] = []

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
    /// leaves when its flow is dismissed. Only `markAttached()`, `markDetached()`,
    /// `join(startedBy:named:flow:)` and `undoJoin()` change it.
    @ObservationIgnored private(set) var isAttached: Bool

    /// Presentation defaults and fallbacks set on this router.
    ///
    /// `var` because an app may set them after creating the router. Only
    /// ``setPresentationDefaults(_:)``, ``setFallback(_:for:file:line:)`` and
    /// ``setDuplicatePushRule(_:)`` change it.
    @ObservationIgnored private var settings = RouterSettings()

    /// The route whose push the renderer is still animating, or `nil` when none is.
    ///
    /// `var` because pushes start and end. Only ``rendererDidStartPush(of:)`` and
    /// ``rendererDidEndPush(of:)`` change it.
    @ObservationIgnored var pushInFlight: AnyRoute?

    /// The interval measuring the push the renderer is still animating, or `nil` when none is or
    /// intervals aren't measured.
    ///
    /// `var` because pushes start and end. Only `beginPushInterval()` and `endPushInterval()`
    /// change it.
    @ObservationIgnored var pushInterval: LogInterval?

    /// How many renderers draw each coordinator on this router right now, by the coordinator's
    /// identity. Several coordinators share one router when tabs share one stack. More than one
    /// renderer for one coordinator is reported as `coordinatorDrawnTwice`.
    ///
    /// `var` because a coordinator's view appears and disappears. Only
    /// `rendererDidStartDrawing(_:)` and `rendererDidStopDrawing(_:)` change it.
    @ObservationIgnored var coordinatorDrawings: [ObjectIdentifier: Int] = [:]

    /// The name of the stack's root screen when it has no root route, or `nil`.
    ///
    /// `var` because a renderer or coordinator names it after the router exists. Only
    /// ``setRootName(_:)`` and `clearRootScreenName()` change it.
    @ObservationIgnored private(set) var rootScreenName: String?

    /// The name of the view that draws the stack's root screen, such as `ProductListView`, or
    /// `nil` when no renderer said.
    ///
    /// `var` because the renderer names it after the router exists. Only `setRootViewName(_:)`
    /// changes it.
    @ObservationIgnored private(set) var rootViewName: String?

    /// The name of the coordinator that owns this stack, or `nil`.
    ///
    /// `var` because the coordinator names itself after the router exists. Only
    /// ``setCoordinator(_:)`` and ``setCoordinatorName(_:)`` change it.
    @ObservationIgnored private(set) var ownerName: String?

    /// An id for each screen on the committed path, bottom first, so a navigator can tell its
    /// screen from another one showing the same route later.
    ///
    /// `var` because screens are pushed and popped. Only `commitWorkingCopy()` changes it.
    @ObservationIgnored private(set) var screenIDs: [UInt64] = []

    /// The screen a navigator is calling for, read once by the call it makes.
    ///
    /// `var` because each navigator call sets it. Only ``calling(from:_:)`` and `perform` change
    /// it.
    @ObservationIgnored private var callingScreen: ScreenBinding?

    /// The flow this stack was declared for, or `nil` when it was declared for none.
    ///
    /// `var` because a renderer or coordinator declares it after the router exists. Only
    /// ``declareFlow(_:)`` changes it.
    @ObservationIgnored private var declaredFlowType: (any NavigationFlow.Type)?

    /// The child flow this router runs for a coordinator a parent started, or `nil`.
    ///
    /// `var` because a flow starts and ends. Only `join(startedBy:named:flow:pushed:)`,
    /// `markDetached()` and `undoJoin()` change it.
    @ObservationIgnored private(set) var childFlow: (any ChildFlowRecord)?

    /// The coordinator of the child flow this router presents, kept while the flow is presented,
    /// so a parent needn't keep it. `nil` when the presented flow has no coordinator.
    ///
    /// `var` because flows are presented and dismissed. Only `commitWorkingCopy(around:)` and
    /// `markDetached()` change it.
    @ObservationIgnored private var presentedCoordinator: AnyObject?

    /// The coordinator of the child flow pushed on top of this stack, kept while the flow is on
    /// the stack, so a parent needn't keep it. `nil` when no child flow is pushed.
    ///
    /// `var` because child flows are pushed and popped. Only `commitWorkingCopy(around:)` and
    /// `markDetached()` change it.
    @ObservationIgnored private var pushedCoordinator: AnyObject?

    /// The route on the parent's path where this router's flow starts, when a parent pushed it,
    /// else `nil`. Kept from the push, so it still matches after the flow is renamed.
    ///
    /// `var` because a child flow is pushed after its router is made. Only
    /// `join(startedBy:named:flow:pushed:)` and `undoJoin()` change it.
    @ObservationIgnored private(set) var marker: AnyRoute?

    /// The tree this router left to join a parent's, kept until the start that joined it
    /// commits, so a rolled-back start can put it back. `nil` otherwise.
    ///
    /// `var` because it is set by a join and cleared by its commit or roll back. Only
    /// `join(startedBy:named:flow:)`, `markAttached()` and `undoJoin()` change it.
    @ObservationIgnored private var joinedFrom: NavigationTreeContext?

    /// The flow name this router had before it joined a parent's tree, kept with `joinedFrom` so
    /// a rolled-back start gives it back.
    ///
    /// `var` because it is set by a join and cleared by its commit or roll back. Only
    /// `join(startedBy:named:flow:pushed:)`, `markAttached()` and `undoJoin()` change it.
    @ObservationIgnored private var nameBeforeJoin: String?

    /// The current state. Change it through the navigation methods below.
    public var state: StackState {
        forwardTarget?.state ?? committed.state
    }

    /// The router of the presented flow, if any.
    public var presented: StackRouter? {
        forwardTarget.map(\.presented) ?? committed.presented
    }

    /// The router of the child flow pushed on top of this stack, if any. Its root screen is the
    /// last route of the path, and its own screens follow on screen.
    package var pushedFlow: StackRouter? {
        forwardTarget.map(\.pushedFlow) ?? committed.pushed
    }

    /// The coordinator of the child flow pushed on top of this stack, which a renderer draws
    /// after this stack's path, or `nil` when no child flow is pushed.
    package var pushedFlowCoordinator: AnyObject? {
        forwardTarget.map(\.pushedFlowCoordinator) ?? pushedCoordinator
    }

    /// The router that presented or contains this one, or `nil` for the root.
    public var parent: (any NavigationRouter)? {
        parentNode
    }

    /// The root router of the whole tree.
    public var root: any NavigationRouter {
        rootNode
    }

    /// The pushed child flow's router, then the presented flow's, if any.
    public var children: [any NavigationRouter] {
        childNodes
    }

    /// Whether this router is still in the tree. When it isn't, every call returns `.ignored`.
    public var isActive: Bool {
        forwardTarget?.isActive ?? isAttached
    }

    /// The flow this stack was declared for with ``declareFlow(_:)``, or `nil`.
    public var declaredFlow: (any NavigationFlow.Type)? {
        declaredFlowType
    }

    /// The name the journey gives the stack's root screen when it has no root route, such as
    /// `Product list`. A root route's own name wins. Unnamed, the root screen takes its tab's
    /// name, else its flow's: `Cart` for the `cart` tab. Set it with ``setRootName(_:)`` or
    /// `WaypointStack(rootName:)`.
    public var rootName: String? {
        rootScreenName
    }

    /// The name of the coordinator that owns this stack, such as `ProductsCoordinator`, shown in
    /// the journey box. Named with ``setCoordinator(_:)`` or ``setCoordinatorName(_:)``; a
    /// presented flow that isn't named takes the name of the coordinator that presented it,
    /// which runs it until it gets its own. Tabs that share one stack name it after the selected
    /// tab's coordinator. `nil` when none is named.
    public var coordinatorName: String? {
        if parentNode?.presentedNode !== self, let shared = parentNode?.sharedStackCoordinatorName {
            return shared
        }
        guard ownerName == nil, let parentNode, parentNode.presentedNode === self else {
            return ownerName
        }
        return parentNode.coordinatorName
    }

    /// The latest visit in this router's whole tree: the screen on display, with where the user
    /// came from. `nil` before the first change and before any stack of the tree appeared.
    public var screenVisit: ScreenVisit? {
        tree.journey.visit
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

    /// What a push of the route still being pushed does, such as the second tap of a double tap.
    /// Unless set here, it comes from the nearest router above, then
    /// ``DuplicatePushRule/skipWhileInFlight``.
    public var duplicatePushRule: DuplicatePushRule {
        settings.duplicatePushRule ?? parentNode?.duplicatePushRule ?? .skipWhileInFlight
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

    /// Creates the router of a child coordinator made while a parent starts it, inside the
    /// parent's `tree` from the start, so calls from the child's `init` get the tree's settings.
    /// It joins its parent when the start commits.
    init(joining tree: NavigationTreeContext, flow name: String) {
        self.tree = tree
        self.flowID = tree.claimFlowName(name)
        self.rootRoute = nil
        self.parentNode = nil
        self.committed = Snapshot(state: StackState(), presented: nil)
        self.isAttached = true
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
    ///
    /// - Parameters:
    ///   - route: The route to push.
    ///   - trigger: What in the screen started the push, such as `related_products`, written in
    ///     the journey box and kept on the ``ScreenVisit``. Default: `nil`.
    ///   - fallback: What to do if the push fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    @discardableResult
    public func push<R: Route>(
        _ route: R,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let routes = [AnyRoute(route)]
        return perform(file: file, line: line, fallback: fallback, trigger: trigger) { router, store in
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
    ///
    /// - Parameters:
    ///   - route: The route of the presented flow's root screen.
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What in the screen started it, such as `checkout_button`, written in the
    ///     journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    @discardableResult
    public func present<R: Route>(
        _ route: R,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let erased = AnyRoute(route)
        let request = PresentationRequest(route: erased, style: style)
        return perform(
            file: file,
            line: line,
            fallback: fallback,
            presentation: request,
            trigger: trigger
        ) { router, store in
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
    /// ├ home     root
    /// ├ shop     root › Product list (…) › Product (id: 42, …)
    /// │ └ sheet checkout  Checkout (…)
    /// └ profile  root
    /// ```
    ///
    /// Route fields are hidden unless `revealingPrivateValues` is `true` or a route lists them
    /// in `publicLogFields`. Separators follow the tree's ``LogConfiguration/usesSymbols``.
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

    /// Sets what a push of the route still being pushed does, for this router and its children.
    ///
    /// ```swift
    /// router.setDuplicatePushRule(.allow)
    /// ```
    public func setDuplicatePushRule(_ rule: DuplicatePushRule) {
        settings = settings.withDuplicatePushRule(rule)
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

    /// Names the stack's root screen in the journey, when the stack has no root route.
    ///
    /// ```swift
    /// router.setRootName("Product list")
    /// ```
    ///
    /// `WaypointStack(rootName:)` names it for you. A root route's own name wins over this one. A
    /// stack the tabs share (``TabStacks/shared``) names its root after the selected tab instead.
    public func setRootName(_ name: String) {
        rootScreenName = name
    }

    /// Forgets the root screen's name. The router table calls this for a tab's child that keeps
    /// the default root name, so the journey names the root screen after its tab.
    func clearRootScreenName() {
        rootScreenName = nil
    }

    /// Names the coordinator that owns this stack in the journey box, by its type.
    ///
    /// ```swift
    /// init(router: StackRouter) {
    ///     self.router = router
    ///     router.setCoordinator(self)
    /// }
    /// ```
    ///
    /// The router keeps only the type's name, never the coordinator.
    public func setCoordinator(_ coordinator: AnyObject) {
        ownerName = ViewTypeName.of(type(of: coordinator))
    }

    /// Names the coordinator that owns this stack in the journey box, such as `Checkout`.
    public func setCoordinatorName(_ name: String) {
        ownerName = name
    }

    /// Names the view that draws the stack's root screen. Renderers call this.
    package func setRootViewName(_ name: String) {
        rootViewName = name
        tree.namesViews = true
    }

    /// Names the view that draws the screens of route type `R` in the journey box. Renderers
    /// call this as they register destinations.
    package func registerViewName<R: Route>(_ name: String, for type: R.Type) {
        tree.viewNames[R.routeKey] = name
        tree.namesViews = true
    }

    /// Declares the flow whose screens this stack shows, so ``navigator(for:file:line:)`` can
    /// tell when a view model asks for another flow's navigator.
    ///
    /// ```swift
    /// router.declareFlow(ShopFlow.self)
    /// ```
    ///
    /// `WaypointStack(flow:)` declares it for you. Declaring another flow replaces the first.
    public func declareFlow<Flow: NavigationFlow>(_ flow: Flow.Type) {
        declaredFlowType = flow
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
        trigger: String? = nil,
        _ step: @escaping (StackRouter, TransactionStore) -> StepResult
    ) -> NavigationOutcome {
        let context = FallbackContext(
            explicit: fallback,
            route: route,
            presentation: presentation,
            file: file,
            line: line
        )
        let screen = takeCallingScreen()
        if let forwardTarget {
            guard screen == .root else {
                return tree.ignoreStale(flowID, file: file, line: line)
            }
            return forwardTarget.perform(
                file: file,
                line: line,
                fallback: fallback,
                route: route,
                presentation: presentation,
                trigger: trigger,
                step
            )
        }
        let isLive = { [weak self] in
            self?.isOnStack(screen) ?? false
        }
        return tree.perform(on: self, file: file, line: line, trigger: trigger, isLive: isLive) { [unowned self] store in
            store.resolve(step(self, store), on: self, context)
        }
    }

    /// Runs `call` as made by a navigator of `screen`, so it is ignored once that screen is
    /// popped, including when it was queued and runs later.
    func calling<Result>(from screen: ScreenBinding, _ call: () -> Result) -> Result {
        callingScreen = screen
        defer {
            callingScreen = nil
        }
        return call()
    }

    /// The screen of the navigator making this call, read once, or the root screen when a
    /// router method was called directly.
    private func takeCallingScreen() -> ScreenBinding {
        let screen = callingScreen ?? .root
        callingScreen = nil
        return screen
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

    /// Writes the working copy once, when it differs, around the other participants' commits,
    /// and swaps the presented router if it changed.
    func commitWorkingCopy(around others: () -> Void) {
        guard let next = working else {
            others()
            return
        }
        working = nil
        let previous = committed
        let swapsPresented = next.presented !== previous.presented
        let swapsPushed = next.pushed !== previous.pushed
        guard next.state != previous.state || swapsPresented || swapsPushed else {
            others()
            return
        }
        withMutation(keyPath: \.committed) {
            others()
            committed = next
        }
        screenIDs = ScreenBinding.ids(screenIDs, from: previous.state.path, to: next.state.path) {
            tree.claimScreenID()
        }
        if swapsPushed {
            pushedCoordinator = swap(previous.pushed, for: next.pushed, keeping: pushedCoordinator)
        }
        if swapsPresented {
            presentedCoordinator = swap(previous.presented, for: next.presented, keeping: presentedCoordinator)
        }
    }

    /// Takes `old` out of the tree and puts `new` in, starting the child flow it runs, and
    /// returns the coordinator to keep from now on, letting `kept` go.
    private func swap(_ old: StackRouter?, for new: StackRouter?, keeping kept: AnyObject?) -> AnyObject? {
        old?.detachSubtree()
        new?.markAttached()
        let started = new?.startChildFlow()
        tree.releaseWhenIdle(kept)
        return started
    }

    /// Drops the working copy, and frees the name of a presented router that never joined, or
    /// puts a child's router that joined back where it was.
    func discardWorkingCopy() {
        if let created = working?.presented, created !== committed.presented {
            releaseUncommitted(created)
        }
        if let created = working?.pushed, created !== committed.pushed {
            releaseUncommitted(created)
        }
        working = nil
    }

    /// Marks this router as in the tree, when the transaction that created it commits.
    func markAttached() {
        isAttached = true
        joinedFrom = nil
        nameBeforeJoin = nil
    }

    /// Starts the child flow this router runs, once the start that presented it commits, and
    /// returns its coordinator for the presenting router to keep. `nil` when it runs none.
    func startChildFlow() -> AnyObject? {
        childFlow?.start()
    }

    /// Marks this router as gone from the tree. Its calls return `.ignored` from now on. A child
    /// flow it runs ends, and its parent gets the result once the current call is done.
    func markDetached() {
        isAttached = false
        tree.releaseWhenIdle(presentedCoordinator)
        presentedCoordinator = nil
        tree.releaseWhenIdle(pushedCoordinator)
        pushedCoordinator = nil
        guard let flow = childFlow, flow.isStarted else {
            return
        }
        childFlow = nil
        tree.runWhenIdle {
            flow.end()
        }
    }
}

/// Joining another tree, for routers made on their own.
extension StackRouter {
    /// Whether this router can join another tree: it was made on its own, so it is the root of
    /// a tree of its own, and it is still in that tree.
    var canJoinAnotherTree: Bool {
        parentNode == nil && isAttached && forwardTarget == nil
    }

    /// Moves this router, made on its own, with every flow it presents, into `parent`'s tree as
    /// a tab's stack named `name`.
    ///
    /// Its path, screens and registered routes are kept. The tree's settings apply from now on.
    func join(tabOf parent: any TreeNode, named name: String) {
        let previous = tree
        moveSubtree(into: parent.tree, from: previous)
        parentNode = parent
        parent.tree.releaseFlowName(flowID)
        flowID = parent.tree.claimFlowName(name)
    }

    /// Moves this router and the flows it presents into `tree`, carrying over the route types and
    /// view names `previous` knows, and taking flow names free in `tree` in place of theirs in
    /// `previous`.
    ///
    /// Without `carryingOver`, `tree` takes nothing from `previous`: a router going back to its
    /// own tree after a rolled-back start keeps that tree's route types and view names only.
    func moveSubtree(
        into tree: NavigationTreeContext,
        from previous: NavigationTreeContext,
        carryingOver: Bool = true
    ) {
        if carryingOver {
            tree.takeOver(previous)
        }
        previous.releaseFlowName(flowID)
        self.tree = tree
        flowID = tree.claimFlowName(flowID.name)
        presented?.moveSubtree(into: tree, from: previous, carryingOver: carryingOver)
        pushedFlow?.moveSubtree(into: tree, from: previous, carryingOver: carryingOver)
    }

    /// Moves this router, made on its own or for a lazy start, with every flow it presents, into
    /// `parent`'s tree as the flow `parent` presents or pushes for a child coordinator, named
    /// `name`, and keeps `flow` until it ends. It stays out of the tree until the start commits.
    ///
    /// With `pushed`, it also gets the marker the parent pushes on its path for it.
    func join(startedBy parent: any TreeNode, named name: String, flow: any ChildFlowRecord, pushed: Bool = false) {
        joinedFrom = tree
        nameBeforeJoin = flowID.name
        if tree !== parent.tree {
            moveSubtree(into: parent.tree, from: tree)
        }
        parentNode = parent
        parent.tree.releaseFlowName(flowID)
        flowID = parent.tree.claimFlowName(name)
        isAttached = false
        childFlow = flow
        marker = pushed ? AnyRoute(ChildFlowRoute(flow: flowID.name)) : nil
    }

    /// Puts a router whose join was rolled back where it was: the root of its own tree again,
    /// with no child flow. Returns `false` when it didn't join.
    func undoJoin() -> Bool {
        guard let previous = joinedFrom else {
            return false
        }
        let parentTree = tree
        let returnsHome = previous !== parentTree
        let home = returnsHome ? previous : NavigationTreeContext(configuration: parentTree.configuration)
        let name = nameBeforeJoin ?? flowID.name
        joinedFrom = nil
        nameBeforeJoin = nil
        childFlow = nil
        marker = nil
        parentNode = nil
        moveSubtree(into: home, from: parentTree, carryingOver: !returnsHome)
        home.releaseFlowName(flowID)
        flowID = home.claimFlowName(name)
        isAttached = true
        return true
    }

    /// Moves a router made for a lazy start that belongs to another coordinator into a tree of
    /// its own, so it never joins the parent's.
    func leaveJoiningTree() {
        let previous = tree
        moveSubtree(into: NavigationTreeContext(configuration: previous.configuration), from: previous)
    }

    /// Sends every call from now on to `target`, which took this router's place and keeps it. A
    /// navigator of the root screen keeps working; one of a pushed screen is stale, and a flow
    /// this router presented leaves the tree.
    func forward(to target: StackRouter) {
        committed.presented?.detachSubtree()
        forwardTarget = target
        target.forwarders.append(self)
        markDetached()
    }
}
