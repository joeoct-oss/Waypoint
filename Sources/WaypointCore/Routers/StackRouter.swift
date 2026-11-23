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
    ///
    /// `var` because a router that joins another tree takes a name that is free there, such as
    /// its tab's. Only `join(tabOf:named:)` and `moveSubtree(into:from:)` change it.
    @ObservationIgnored public private(set) var flowID: FlowID

    /// The route of the stack's root screen, if it has one. `popTo` this route pops to root.
    @ObservationIgnored public let rootRoute: AnyRoute?

    /// The tree this router belongs to.
    ///
    /// `var` because a router made on its own joins another tree once, such as a tab child's
    /// router becoming the tab's stack. Only `join(tabOf:named:)` and `moveSubtree(into:from:)` change
    /// it.
    @ObservationIgnored private(set) var tree: NavigationTreeContext

    /// The router that presented or contains this one.
    ///
    /// `var` because a router made on its own gets a parent when it joins another tree. Only
    /// `join(tabOf:named:)` changes it.
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
    /// leaves when its flow is dismissed. Only `markAttached()` and `markDetached()` change it.
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

    /// The current state. Change it through the navigation methods below.
    public var state: StackState {
        forwardTarget?.state ?? committed.state
    }

    /// The router of the presented flow, if any.
    public var presented: StackRouter? {
        forwardTarget.map(\.presented) ?? committed.presented
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
        guard next.state != previous.state || next.presented !== previous.presented else {
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
    /// view names `previous` knows, and taking flow names free in `tree`.
    func moveSubtree(into tree: NavigationTreeContext, from previous: NavigationTreeContext) {
        tree.takeOver(previous)
        self.tree = tree
        flowID = tree.claimFlowName(flowID.name)
        presented?.moveSubtree(into: tree, from: previous)
    }

    /// Sends every call from now on to `target`, which took this router's place and keeps it. A
    /// navigator of the root screen keeps working; one of a pushed screen is stale.
    func forward(to target: StackRouter) {
        forwardTarget = target
        target.forwarders.append(self)
        markDetached()
    }
}
