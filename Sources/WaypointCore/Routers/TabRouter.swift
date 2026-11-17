//
//  TabRouter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

/// The owner of a tab container.
///
/// Each tab has its own stack router, so every tab keeps its own stack when the user switches
/// away and back.
///
/// ```swift
/// let tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)
/// tabs.select(.shop)
/// tabs.router(for: .shop).push(ProductRoute(id: 42))
/// ```
///
/// `Tab` is usually an app enum. Its `String` raw value or case name is what logs and changes
/// show.
///
/// Conformances:
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
/// - `NavigationRouter`, so it takes part in the router tree.
/// - `Observable`, so renderers and views redraw when the state changes.
@MainActor
@Observable
public final class TabRouter<Tab: Hashable & Codable & Sendable>: NavigationRouter {
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

    /// The flow this router drives.
    @ObservationIgnored public let flowID: FlowID

    /// The tree this router belongs to.
    @ObservationIgnored let tree: NavigationTreeContext

    /// The router that presented or contains this one.
    @ObservationIgnored weak let parentNode: (any TreeNode)?

    /// The committed state, presented router and tab routers, which renderers observe.
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
    /// `var` because a router leaves the tree when its flow is dismissed. Only `markAttached()`
    /// and `markDetached()` change it.
    @ObservationIgnored private(set) var isAttached = true

    /// Presentation defaults and fallbacks set on this router.
    ///
    /// `var` because an app may set them after creating the router. Only
    /// ``setPresentationDefaults(_:)`` and ``setFallback(_:for:file:line:)`` change it.
    @ObservationIgnored private var settings = RouterSettings()

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

    /// The route types registered in this tree, for decoding and as destinations.
    public var registry: RouteRegistry {
        tree.registry
    }

    /// The most calls that may be queued while changes are applied, in one main-actor turn.
    /// Shared by the whole tree. Default: 32.
    public var maxQueuedChanges: Int {
        tree.maxQueuedChanges
    }

    /// How this router's whole tree logs. Shared by every router in the tree.
    /// Default: ``LogConfiguration/default``.
    public var logging: LogConfiguration {
        tree.logging
    }

    /// Default presentation options for this container, its tabs and their children.
    public var presentationDefaults: PresentationDefaults {
        settings.presentationDefaults ?? parentNode?.presentationDefaults ?? .default
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
    ///   - popsToRootOnReselect: Whether tapping the selected tab pops its stack to the root.
    ///     Default: `true`.
    public init(
        tabs: [Tab],
        selection: Tab,
        flow: FlowID = FlowID("tabs"),
        popsToRootOnReselect: Bool = true
    ) {
        let tree = NavigationTreeContext()
        let state = TabState(tabs: tabs, selection: selection)
        self.tree = tree
        self.flowID = tree.claimFlowName(flow.name)
        self.parentNode = nil
        self.popsToRootOnReselect = popsToRootOnReselect
        self.committed = Snapshot(state: state, presented: nil, tabRouters: [:])
        // The tab routers need `self` as their parent, so they are added once `self` exists.
        let routers = state.tabs.map { tab in
            (tab, makeTabRouter(for: tab, attached: true))
        }
        self.committed = Snapshot(state: state, presented: nil, tabRouters: Dictionary(uniqueKeysWithValues: routers))
    }

    /// The stack router of one tab.
    ///
    /// A tab that isn't one of `tabs` gets a router that is not in the tree, so its calls return
    /// `.ignored`.
    public func router(for tab: Tab) -> StackRouter {
        tabRouters[tab] ?? makeTabRouter(for: tab, attached: false)
    }

    /// Selects a tab.
    ///
    /// Returns `.alreadyThere` if it is selected, unless ``popsToRootOnReselect`` pops its
    /// stack. Fails with `unknownTab` if it is not one of the tabs.
    @discardableResult
    public func select(
        _ tab: Tab,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.selectStep(tab, in: store)
        }
    }

    /// Replaces the list of tabs.
    ///
    /// If the selected tab is removed, the first tab is selected. A removed tab's stack leaves
    /// the tree. An empty list fails with `unknownTab`.
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

    /// Sets how this router's whole tree logs. Set it once, on the root.
    ///
    /// ```swift
    /// tabs.setLogging(LogConfiguration.default.withMinimumLevel(.debug))
    /// ```
    public func setLogging(_ configuration: LogConfiguration) {
        tree.setLogging(configuration)
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

    /// Sets the most calls that may be queued in one main-actor turn, for the whole tree.
    ///
    /// A limit below 1 would drop every call made from an observer, so it reports
    /// `invalidSetting` and the limit stays as it was.
    public func setMaxQueuedChanges(_ limit: Int, file: StaticString = #fileID, line: UInt = #line) {
        guard let problem = tree.setMaxQueuedChanges(limit) else {
            return
        }
        reportInvalidSetting(problem, file: file, line: line)
    }

    /// Sets the default presentation options for this router and its children.
    ///
    /// ```swift
    /// tabs.setPresentationDefaults(PresentationDefaults(sheet: SheetOptions(detents: [.medium, .large])))
    /// ```
    public func setPresentationDefaults(_ defaults: PresentationDefaults) {
        settings = settings.withPresentationDefaults(defaults)
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

    /// Registers a route type for decoding and as having a destination. See
    /// ``StackRouter/register(_:)``.
    public func register<R: Route>(_ type: R.Type) {
        tree.register(type)
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
        _ step: @escaping (TabRouter, TransactionStore) -> StepResult
    ) -> NavigationOutcome {
        let context = FallbackContext(explicit: fallback, route: route, file: file, line: line)
        return tree.perform(on: self, file: file, line: line) { [unowned self] store in
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

    /// Writes the working copy once, when it differs, and swaps routers that changed.
    func commitWorkingCopy() {
        guard let next = working else {
            return
        }
        working = nil
        let previous = committed
        let routersChanged = next.tabRouters.count != previous.tabRouters.count
            || next.tabRouters.contains { tab, router in
                previous.tabRouters[tab] !== router
            }
        guard next.state != previous.state || next.presented !== previous.presented || routersChanged else {
            return
        }
        committed = next
        commitTabRouters(from: previous.tabRouters, to: next.tabRouters)
        commitPresented(from: previous.presented, to: next.presented)
    }

    /// Drops the working copy, and frees the names of routers that never joined.
    func discardWorkingCopy() {
        guard let dropped = working else {
            return
        }
        working = nil
        let created = dropped.tabRouters.values.filter { router in
            !committed.tabRouters.values.contains { $0 === router }
        }
        let presentedCreated = dropped.presented.flatMap { $0 === committed.presented ? nil : $0 }
        for router in created + (presentedCreated.map { [$0] } ?? []) {
            tree.releaseFlowName(router.flowID)
        }
    }

    /// Marks this router as in the tree.
    func markAttached() {
        isAttached = true
    }

    /// Marks this router as gone from the tree. Its calls return `.ignored` from now on.
    func markDetached() {
        isAttached = false
    }

    /// Detaches removed tab routers and attaches new ones.
    private func commitTabRouters(from previous: [Tab: StackRouter], to next: [Tab: StackRouter]) {
        for (tab, router) in previous where next[tab] !== router {
            router.detachSubtree()
        }
        for router in next.values {
            router.markAttached()
        }
    }

    /// Detaches the old presented router and attaches the new one, if it changed.
    private func commitPresented(from previous: StackRouter?, to next: StackRouter?) {
        guard next !== previous else {
            return
        }
        previous?.detachSubtree()
        next?.markAttached()
    }
}
