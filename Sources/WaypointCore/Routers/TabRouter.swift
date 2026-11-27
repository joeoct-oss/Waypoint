//
//  TabRouter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

/// The owner of a tab container.
///
/// By default each tab has its own stack router, so every tab keeps its own stack when the user
/// switches away and back. With ``TabStacks/shared``, the tabs share one stack above the tab bar
/// instead.
///
/// ```swift
/// let tabs = TabRouter(selection: MainTab.home)
/// tabs.select(.shop)
/// tabs.router(for: .shop).push(ProductRoute(id: 42))
/// ```
///
/// `Tab` is usually an app enum. Its `String` raw value or case name is what logs and changes
/// show.
///
/// Conformances:
/// - `Tab: NavigationTab`, the app's tab type, which is selected and compared, saved and restored,
///   and named in events off the main actor.
/// - `NavigationRouter`, so it takes part in the router tree.
/// - `Observable`, so renderers and views redraw when the state changes.
@MainActor
@Observable
public final class TabRouter<Tab: NavigationTab>: NavigationRouter {
    /// What a tab router shows: its state, the router of the flow presented above it, and each
    /// tab's router.
    struct Snapshot {
        /// The container's state.
        let state: TabState<Tab>

        /// The router of the presented flow, if any.
        let presented: StackRouter?

        /// Each tab's stack router.
        let tabRouters: [Tab: StackRouter]

        /// The same snapshot with another state.
        func withState(_ state: TabState<Tab>) -> Snapshot {
            Snapshot(state: state, presented: presented, tabRouters: tabRouters)
        }

        /// The same snapshot with other tab routers.
        func withTabRouters(_ tabRouters: [Tab: StackRouter]) -> Snapshot {
            Snapshot(state: state, presented: presented, tabRouters: tabRouters)
        }

        /// The same snapshot presenting another flow, or none.
        func presenting(_ presentation: Presentation?, by router: StackRouter?) -> Snapshot {
            Snapshot(state: state.withPresentation(presentation), presented: router, tabRouters: tabRouters)
        }
    }

    /// Whether tapping the selected tab pops its stack to the root. Default: `true`.
    @ObservationIgnored public let popsToRootOnReselect: Bool

    /// Where the tabs' pushed screens go. Default: ``TabStacks/perTab``.
    @ObservationIgnored public let stacks: TabStacks

    /// The flow this router drives.
    @ObservationIgnored public let flowID: FlowID

    /// The tree this router belongs to.
    @ObservationIgnored let tree: NavigationTreeContext

    /// The router that presented or contains this one.
    @ObservationIgnored weak let parentNode: (any TreeNode)?

    /// The committed state, presented router and tab routers, which renderers observe.
    ///
    /// `var` because it is the router's current value. Only `commitWorkingCopy()` and
    /// `adoptTabRouter(_:for:)` replace it.
    private var committed: Snapshot

    /// The copy a transaction changes, or `nil` between transactions.
    ///
    /// `var` because a transaction changes it step by step. Only the working-copy functions in
    /// this file change it.
    @ObservationIgnored private var working: Snapshot?

    /// The coordinator of the child flow this container presents, kept while the flow is
    /// presented, so a parent needn't keep it. `nil` when the presented flow has no coordinator.
    ///
    /// `var` because flows are presented and dismissed. Only `commitPresented(from:to:)` and
    /// `markDetached()` change it.
    @ObservationIgnored private var presentedCoordinator: AnyObject?

    /// Whether this router is in the tree.
    ///
    /// `var` because a router leaves the tree when its flow is dismissed. Only `markAttached()`
    /// and `markDetached()` change it.
    @ObservationIgnored private(set) var isAttached = true

    /// Presentation defaults and fallbacks set on this router.
    ///
    /// `var` because an app may set them after creating the router. Only
    /// ``setPresentationDefaults(_:)``, ``setFallback(_:for:file:line:)`` and
    /// ``setDuplicatePushRule(_:)`` change it.
    @ObservationIgnored private var settings = RouterSettings()

    /// The name of the coordinator that owns this container, or `nil`.
    ///
    /// `var` because the coordinator names itself after the router exists. Only
    /// ``setCoordinator(_:)`` and ``setCoordinatorName(_:)`` change it.
    @ObservationIgnored private var ownerName: String?

    /// The name of each tab's child coordinator, so the shared stack is named after the
    /// selected tab's coordinator.
    ///
    /// `var` because tab coordinators name their children as they join. Only
    /// `nameTabCoordinator(_:for:)` and `forgetTabCoordinator(for:)` change it.
    @ObservationIgnored private var tabCoordinatorNames: [Tab: String] = [:]

    /// What the tab coordinator runs when tabs are added or removed, so it asks for the new
    /// tabs' children and lets the removed ones go, or `nil` without a tab coordinator.
    ///
    /// `var` because the tab coordinator sets it once it joins. Only `onTabsChanged(_:)`
    /// changes it.
    @ObservationIgnored private var tabsChanged: ((_ added: [Tab], _ removed: [Tab]) -> Void)?

    /// The current state. Change it through the navigation methods below.
    public var state: TabState<Tab> {
        committed.state
    }

    /// The router of the flow presented above the whole container, if any.
    public var presented: StackRouter? {
        committed.presented
    }

    /// The selected tab.
    public var selection: Tab {
        state.selection
    }

    /// The router that presented or contains this one, or `nil` for the root.
    public var parent: (any NavigationRouter)? {
        parentNode
    }

    /// The root router of the whole tree.
    public var root: any NavigationRouter {
        rootNode
    }

    /// Each tab's stack router in tab order, then the presented flow's router.
    public var children: [any NavigationRouter] {
        childNodes
    }

    /// Whether this router is still in the tree. When it isn't, every call returns `.ignored`.
    public var isActive: Bool {
        isAttached
    }

    /// The name of the coordinator that owns this container, such as `MainCoordinator`, shown in
    /// the journey box. `nil` until ``setCoordinator(_:)`` or ``setCoordinatorName(_:)`` names
    /// it.
    public var coordinatorName: String? {
        ownerName
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

    /// Default presentation options for this container, its tabs and their children.
    public var presentationDefaults: PresentationDefaults {
        settings.presentationDefaults ?? parentNode?.presentationDefaults ?? .default
    }

    /// What a push of the route still being pushed does, such as the second tap of a double tap.
    /// Unless set here, it comes from the nearest router above, then
    /// ``DuplicatePushRule/skipWhileInFlight``.
    public var duplicatePushRule: DuplicatePushRule {
        settings.duplicatePushRule ?? parentNode?.duplicatePushRule ?? .skipWhileInFlight
    }

    /// What to do when a call fails and passes no fallback, by issue kind. See
    /// ``StackRouter/fallbackPolicy``.
    public var fallbackPolicy: FallbackPolicy {
        settings.fallbackPolicy
    }

    /// Each tab's committed stack router.
    var tabRouters: [Tab: StackRouter] {
        committed.tabRouters
    }

    /// The selected tab's name with ``TabStacks/shared``, so the journey names the tab the reader
    /// sees, such as `Shop`, rather than the shared stack.
    var sharedStackTabName: String? {
        stacks == .shared ? DescriptionFormat.name(of: current.state.selection) : nil
    }

    /// The selected tab's child coordinator's name with ``TabStacks/shared``, so the shared
    /// stack is named after the coordinator of the tab the reader sees.
    var sharedStackCoordinatorName: String? {
        stacks == .shared ? tabCoordinatorNames[current.state.selection] : nil
    }

    /// The working copy during a transaction, or the committed snapshot.
    var current: Snapshot {
        working ?? committed
    }

    /// Creates a root tab container.
    ///
    /// `selection` should be one of `tabs`. If it isn't, the first tab is selected; with no tabs,
    /// `selection` becomes the only tab.
    ///
    /// - Parameters:
    ///   - tabs: The tabs, in the order they are shown.
    ///   - selection: The tab selected at the start.
    ///   - flow: The container's name in logs, events and saved state. Default: `tabs`.
    ///   - stacks: Where the tabs' pushed screens go: one stack per tab, or one stack shared
    ///     above the tab bar. Default: ``TabStacks/perTab``.
    ///   - popsToRootOnReselect: Whether tapping the selected tab pops its stack to the root.
    ///     Default: `true`.
    ///   - configuration: The settings of the whole tree. Default:
    ///     ``NavigationConfiguration/default``.
    ///   - file: The file that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    ///   - line: The line that makes the router, where a configuration problem is reported.
    ///     Leave the default.
    public init(
        tabs: [Tab],
        selection: Tab,
        flow: FlowID = FlowID("tabs"),
        stacks: TabStacks = .perTab,
        popsToRootOnReselect: Bool = true,
        configuration: NavigationConfiguration = .default,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let tree = NavigationTreeContext(configuration: configuration)
        let state = TabState(tabs: tabs, selection: selection)
        self.tree = tree
        self.flowID = tree.claimFlowName(flow.name)
        self.parentNode = nil
        self.popsToRootOnReselect = popsToRootOnReselect
        self.stacks = stacks
        let noTabRouters: [Tab: StackRouter] = [:]
        self.committed = Snapshot(state: state, presented: nil, tabRouters: noTabRouters)
        // The tab routers need `self` as their parent, so they are added once `self` exists.
        let shared = stacks == .shared ? makeSharedRouter() : nil
        let routers = state.tabs.map { tab in
            (tab, shared ?? makeTabRouter(for: tab, attached: true))
        }
        self.committed = Snapshot(state: state, presented: nil, tabRouters: Dictionary(uniqueKeysWithValues: routers))
        if let problem = tree.configurationProblem {
            reportInvalidSetting(problem, file: file, line: line)
        }
    }

    /// The stack router of one tab. With ``TabStacks/shared`` it is the same router for every
    /// tab.
    ///
    /// A tab that isn't one of `tabs` gets a router that is not in the tree, so its calls return
    /// `.ignored`.
    public func router(for tab: Tab) -> StackRouter {
        tabRouters[tab] ?? makeTabRouter(for: tab, attached: false)
    }

    /// Selects a tab.
    ///
    /// Returns `.alreadyThere` if it is selected, unless ``popsToRootOnReselect`` pops its
    /// stack. Fails with `unknownTab` if it is not one of the tabs. With ``TabStacks/shared``,
    /// selecting another tab pops the shared stack in the same change.
    ///
    /// - Parameters:
    ///   - tab: The tab to select.
    ///   - trigger: What started the switch, such as `added_to_cart`, written on the journey
    ///     lines. Default: `nil`.
    ///   - fallback: What to do if the selection fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    @discardableResult
    public func select(
        _ tab: Tab,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback, trigger: trigger) { router, store in
            router.selectStep(tab, in: store)
        }
    }

    /// Replaces the list of tabs.
    ///
    /// If the selected tab is removed, the first tab is selected. A removed tab's stack leaves
    /// the tree. With ``TabStacks/shared`` the shared stack stays while any tab is left, and it
    /// pops when the selection moves. An empty list fails with `unknownTab`.
    @discardableResult
    public func setTabs(
        _ tabs: [Tab],
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.setTabsStep(tabs, in: store)
        }
    }

    /// Presents `route` above the whole tab container, as the root screen of a new child flow.
    ///
    /// - Parameters:
    ///   - route: The route of the presented flow's root screen.
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What started it, written in the journey box. Default: `nil`.
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

    /// Presents the flow of `child`, a coordinator, above the whole tab container, as
    /// ``StackRouter/present(_:style:trigger:else:file:line:onFinish:)`` does above a stack.
    ///
    /// - Parameters:
    ///   - child: The coordinator of the presented flow.
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    @discardableResult
    public func present<Child: FlowCoordinating>(
        _ child: Child,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void
    ) -> NavigationOutcome {
        present(style: style, trigger: trigger, else: fallback, file: file, line: line, onFinish: onFinish) {
            child
        }
    }

    /// Presents the flow of the coordinator `makeChild` returns, above the whole tab container,
    /// building it only when the present happens, as
    /// ``StackRouter/present(style:trigger:else:file:line:onFinish:_:)`` does above a stack.
    ///
    /// - Parameters:
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    ///   - makeChild: Builds the coordinator of the presented flow.
    @discardableResult
    public func present<Child: FlowCoordinating>(
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: @escaping @MainActor () -> Child
    ) -> NavigationOutcome {
        let request = PresentationRequest { router, store in
            router.presentChildStep(style: style, file: file, line: line, in: store, onFinish: onFinish, makeChild)
        }
        return perform(
            file: file,
            line: line,
            fallback: fallback,
            presentation: request,
            trigger: trigger
        ) { router, store in
            request.step(router, store)
        }
    }

    /// Dismisses the flow presented above the container. Returns `.alreadyThere` when nothing is.
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

    /// Dismisses everything presented above the container and above each tab.
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
    /// tabs.setPresentationDefaults(PresentationDefaults(sheet: sheet))
    /// ```
    public func setPresentationDefaults(_ defaults: PresentationDefaults) {
        settings = settings.withPresentationDefaults(defaults)
    }

    /// Sets what a push of the route still being pushed does, for this router and its children.
    ///
    /// ```swift
    /// tabs.setDuplicatePushRule(.allow)
    /// ```
    public func setDuplicatePushRule(_ rule: DuplicatePushRule) {
        settings = settings.withDuplicatePushRule(rule)
    }

    /// Sets what to do when a call of this kind fails and passes no fallback, for this flow and
    /// its children. `nil` inherits the parent's entry again.
    ///
    /// ```swift
    /// tabs.setFallback(.popToRoot, for: .routeNotInPath)
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

    /// Names the coordinator that owns this container in the journey box, by its type. The
    /// router keeps only the type's name, never the coordinator.
    public func setCoordinator(_ coordinator: AnyObject) {
        ownerName = ViewTypeName.of(type(of: coordinator))
    }

    /// Names the coordinator that owns this container in the journey box, such as `Main`.
    public func setCoordinatorName(_ name: String) {
        ownerName = name
    }

    /// Registers a route type for decoding and as having a destination. See
    /// ``StackRouter/register(_:)``.
    public func register<R: Route>(_ type: R.Type) {
        tree.register(type)
    }

    /// Makes `router`, the own router of `tab`'s child coordinator, the stack of `tab`. It joins
    /// this tree with its screens, and the stack it replaces forwards to it, so a navigator of
    /// that stack's root screen keeps working. With ``TabStacks/shared`` it becomes the stack of
    /// every tab.
    func adoptTabRouter(_ router: StackRouter, for tab: Tab) {
        guard let replaced = current.tabRouters[tab], replaced !== router else {
            return
        }
        let name = stacks == .shared ? replaced.flowID.name : DescriptionFormat.name(of: tab)
        tree.releaseFlowName(replaced.flowID)
        router.join(tabOf: self, named: name)
        replaced.forward(to: router)
        let swap = { (snapshot: Snapshot) in
            snapshot.withTabRouters(snapshot.tabRouters.mapValues { $0 === replaced ? router : $0 })
        }
        updateWorkingCopy(swap)
        withMutation(keyPath: \.committed) {
            committed = swap(committed)
        }
    }

    /// Names the child coordinator of `tab`, for the shared stack's name.
    func nameTabCoordinator(_ name: String, for tab: Tab) {
        tabCoordinatorNames[tab] = name
    }

    /// Forgets the child coordinator of a removed tab.
    func forgetTabCoordinator(for tab: Tab) {
        tabCoordinatorNames.removeValue(forKey: tab)
    }

    /// Sets what runs after a change adds or removes tabs.
    func onTabsChanged(_ handler: @escaping (_ added: [Tab], _ removed: [Tab]) -> Void) {
        tabsChanged = handler
    }

    /// Creates the one stack the tabs share with ``TabStacks/shared``.
    private func makeSharedRouter() -> StackRouter {
        StackRouter(tabOf: self, flow: tree.claimFlowName("stack"), isAttached: true)
    }

    /// Creates the stack router of one tab.
    private func makeTabRouter(for tab: Tab, attached: Bool) -> StackRouter {
        let name = DescriptionFormat.name(of: tab)
        let flow = attached ? tree.claimFlowName(name) : FlowID(name)
        return StackRouter(tabOf: self, flow: flow, isAttached: attached)
    }

    /// Runs a call on this router as one transaction, with its fallback if it fails.
    private func perform(
        file: StaticString,
        line: UInt,
        fallback: NavigationFallback?,
        route: AnyRoute? = nil,
        presentation: PresentationRequest? = nil,
        trigger: String? = nil,
        _ step: @escaping (TabRouter, TransactionStore) -> StepResult
    ) -> NavigationOutcome {
        let context = FallbackContext(
            explicit: fallback,
            route: route,
            presentation: presentation,
            file: file,
            line: line
        )
        return tree.perform(on: self, file: file, line: line, trigger: trigger) { [unowned self] store in
            store.resolve(step(self, store), on: self, context)
        }
    }
}

/// Conformances:
/// - `TransactionParticipant`, so a transaction can change it on a working copy.
extension TabRouter: TransactionParticipant {
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
    /// and swaps routers that changed.
    func commitWorkingCopy(around others: () -> Void) {
        guard let next = working else {
            others()
            return
        }
        working = nil
        let previous = committed
        let routersChanged =
            next.tabRouters.count != previous.tabRouters.count
            || next.tabRouters.contains { tab, router in
                previous.tabRouters[tab] !== router
            }
        guard next.state != previous.state || next.presented !== previous.presented || routersChanged else {
            others()
            return
        }
        withMutation(keyPath: \.committed) {
            others()
            committed = next
        }
        commitTabRouters(from: previous.tabRouters, to: next.tabRouters)
        commitPresented(from: previous.presented, to: next.presented)
        reportTabsChanged(from: previous.state.tabs, to: next.state.tabs)
    }

    /// Drops the working copy, and frees the names of routers that never joined, or puts a child's
    /// router that joined back where it was.
    func discardWorkingCopy() {
        guard let dropped = working else {
            return
        }
        working = nil
        let created = dropped.tabRouters.values.filter { router in
            !committed.tabRouters.values.contains { $0 === router }
        }
        for router in created {
            tree.releaseFlowName(router.flowID)
        }
        if let presentedCreated = dropped.presented, presentedCreated !== committed.presented {
            releaseUncommitted(presentedCreated)
        }
    }

    /// Marks this router as in the tree.
    func markAttached() {
        isAttached = true
    }

    /// Marks this router as gone from the tree. Its calls return `.ignored` from now on.
    func markDetached() {
        isAttached = false
        tree.releaseWhenIdle(presentedCoordinator)
        presentedCoordinator = nil
    }

    /// Detaches tab routers that no tab uses any more, and attaches new ones. A shared stack stays
    /// while any tab uses it.
    private func commitTabRouters(from previous: [Tab: StackRouter], to next: [Tab: StackRouter]) {
        for router in previous.values where !next.values.contains(where: { $0 === router }) {
            router.detachSubtree()
        }
        for router in next.values {
            router.markAttached()
        }
    }

    /// Tells the tab coordinator which tabs a change added and removed, once the call and the
    /// calls it queued are done, so a new child's calls from its `init` apply at once.
    private func reportTabsChanged(from previous: [Tab], to next: [Tab]) {
        guard tabsChanged != nil, previous != next else {
            return
        }
        let added = next.filter { !previous.contains($0) }
        let removed = previous.filter { !next.contains($0) }
        guard !added.isEmpty || !removed.isEmpty else {
            return
        }
        tree.runAfterTurn { [weak self] in
            self?.tabsChanged?(added, removed)
        }
    }

    /// Detaches the old presented router and attaches the new one, if it changed.
    private func commitPresented(from previous: StackRouter?, to next: StackRouter?) {
        guard next !== previous else {
            return
        }
        previous?.detachSubtree()
        next?.markAttached()
        let started = next?.startChildFlow()
        tree.releaseWhenIdle(presentedCoordinator)
        presentedCoordinator = started
    }
}
