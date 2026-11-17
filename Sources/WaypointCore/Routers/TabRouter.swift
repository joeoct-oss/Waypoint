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
    /// The working copy of a tab router during a transaction.
    struct Working {
        /// The state being changed.
        var state: TabState<Tab>

        /// The presented router being changed.
        var presented: StackRouter?

        /// Each tab's router, being changed.
        var tabRouters: [Tab: StackRouter]
    }

    /// The current state. Change it only through the methods below.
    public internal(set) var state: TabState<Tab>

    /// The router of the flow presented above the whole container, if any.
    public internal(set) var presented: StackRouter?

    /// Whether tapping the selected tab pops its stack to the root. Default: `true`.
    public var popsToRootOnReselect = true

    /// The flow this router drives.
    @ObservationIgnored public let flowID: FlowID

    /// Each tab's stack router.
    @ObservationIgnored var tabRouters: [Tab: StackRouter] = [:]

    /// The tree this router belongs to.
    @ObservationIgnored let tree: NavigationTreeContext

    /// The router that presented or contains this one.
    @ObservationIgnored private(set) weak var parentNode: (any TreeNode)?

    /// Whether this router is in the tree.
    @ObservationIgnored var isAttached = true

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

    /// Creates a root tab container.
    ///
    /// `selection` should be one of `tabs`. If it isn't, the first tab is selected; with no tabs,
    /// `selection` becomes the only tab.
    ///
    /// - Parameter flow: The container's name in logs, events and saved state. Default: `tabs`.
    public init(tabs: [Tab], selection: Tab, flow: FlowID = FlowID("tabs")) {
        let tree = NavigationTreeContext()
        let tabs = tabs.isEmpty ? [selection] : tabs
        self.tree = tree
        self.flowID = tree.claimFlowName(flow.name)
        self.state = TabState(tabs: tabs, selection: tabs.contains(selection) ? selection : tabs[0])
        self.tabRouters = Dictionary(uniqueKeysWithValues: tabs.map { ($0, makeTabRouter(for: $0, attached: true)) })
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
        get {
            tree.maxQueuedChanges
        }
        set {
            tree.maxQueuedChanges = newValue
        }
    }

    /// How this router's whole tree logs. Shared by every router in the tree, so set it once on
    /// the root. Default: ``LogConfiguration/default``.
    public var logging: LogConfiguration {
        get {
            tree.logging
        }
        set {
            tree.logging = newValue
        }
    }

    /// Default presentation options for this container, its tabs and their children.
    public var presentationDefaults: PresentationDefaults {
        get {
            ownPresentationDefaults ?? parentNode?.presentationDefaults ?? .default
        }
        set {
            ownPresentationDefaults = newValue
        }
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
