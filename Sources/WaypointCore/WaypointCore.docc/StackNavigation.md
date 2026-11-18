# Stack navigation

Push, pop and replace screens with a stack router, and know what every call did.

## Overview

`StackRouter` owns one stack. Its methods read like what they do, take your own route types, and change the state in one step that the renderer draws.

```swift
router.push(ProductRoute(id: 42))
router.pop()
router.popTo(CartRoute.self)
router.popToRoot()
```

Views and view models usually get a `StackNavigator` or a `FlowNavigator` instead of the router, so they can navigate without owning state.

### The stack router

Every navigation method returns a `NavigationOutcome`. The result is discardable, so the common case reads as above. Methods never throw. Each one also takes an optional fallback and records the caller's file and line for diagnostics:

```swift
else fallback: NavigationFallback? = nil, file: StaticString = #fileID, line: UInt = #line
```

The signatures below leave those three parameters out to stay readable.

```swift
/// The owner of one navigation stack.
@MainActor @Observable
public final class StackRouter {
    /// The route of the stack's root screen, if it has one.
    public let rootRoute: AnyRoute?

    /// The current state. Change it only through the methods below.
    public var state: StackState { get }

    // Pushing

    /// The flow this router drives.
    public var flowID: FlowID { get }
    /// The router that presented or contains this one, or `nil` for the root.
    public var parent: (any NavigationRouter)? { get }

    /// Whether this router is still in the tree. A router whose flow was
    /// dismissed ignores every call and returns `.ignored`.
    public var isActive: Bool { get }

    // Destinations
    /// The route types registered in this tree.
    public var registry: RouteRegistry { get }

    /// The settings of the whole tree, given once to the root router.
    public var configuration: NavigationConfiguration { get }

    // Handles

    /// A handle that can navigate this stack with any route.
    public var navigator: StackNavigator { get }
    /// What to do when a call fails and passes no fallback. Children inherit it.
    public var fallbackPolicy: FallbackPolicy { get }
    /// What a push of the route still being pushed does. Children inherit it.
    /// Default: `.skipWhileInFlight`.
    public var duplicatePushRule: DuplicatePushRule { get }

    /// Creates a root router with an empty path. `flow` names it in logs,
    /// events and saved state, and `configuration` holds the settings of the
    /// whole tree.
    public convenience init(
        flow: FlowID = FlowID("main"),
        configuration: NavigationConfiguration = .default,
        file: StaticString = #fileID,
        line: UInt = #line
    )

    /// Creates a root router whose root screen shows `root`, so `popTo(root)`
    /// pops to the root.
    public convenience init<R: Route>(
        root: R,
        flow: FlowID = FlowID("main"),
        configuration: NavigationConfiguration = .default,
        file: StaticString = #fileID,
        line: UInt = #line
    )

    /// Sets one kind's fallback for this flow and its children, or clears it with `nil`.
    /// `.push` for any kind but `routeNotInPath` reports `invalidSetting` and changes nothing.
    public func setFallback(
        _ fallback: NavigationFallback?,
        for kind: NavigationIssue.Kind,
        file: StaticString = #fileID,
        line: UInt = #line
    )

    /// Sets what a push of the route still being pushed does, for this flow
    /// and its children.
    public func setDuplicatePushRule(_ rule: DuplicatePushRule)

    /// Pushes one route.
    @discardableResult public func push<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// Pushes several routes as one change, with one animation.
    @discardableResult public func push(
        else fallback: NavigationFallback? = nil,
        @RoutePathBuilder _ routes: () -> [AnyRoute]
    ) -> NavigationOutcome

    // Popping

    /// Pops `count` routes. Popping more than the path holds pops to the root
    /// and returns `.recovered`.
    @discardableResult public func pop(
        count: Int = 1,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// Pops to the last occurrence of `route`.
    ///
    /// Returns `.alreadyThere` if it is on top. If the route is the stack's
    /// root screen, this pops to root.
    @discardableResult public func popTo<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// Pops to the last route of type `R` that matches `predicate`.
    @discardableResult public func popTo<R: Route>(
        _ type: R.Type,
        else fallback: NavigationFallback? = nil,
        where predicate: @escaping (R) -> Bool = { _ in true }
    ) -> NavigationOutcome

    /// Empties the path, showing the root screen.
    @discardableResult public func popToRoot(
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    // Replacing

    /// Replaces the whole path as one change.
    @discardableResult public func setPath(
        else fallback: NavigationFallback? = nil,
        @RoutePathBuilder _ routes: () -> [AnyRoute]
    ) -> NavigationOutcome

    // Reading

    /// Whether the path contains this route.
    public func contains<R: Route>(_ route: R) -> Bool
    /// The route of type `R` nearest the top of the path, or `nil`.
    public func last<R: Route>(_ type: R.Type) -> R?

    // Several changes as one

    /// Applies several changes as one: the state changes once, the renderer
    /// draws once, and observers get one batch.
    ///
    /// If any step ends `.failed`, the whole transaction is rolled back, and
    /// the outcome is that step's failure with the step's file and line.
    @discardableResult public func transaction(
        _ body: @escaping (NavigationTransaction) -> Void
    ) -> NavigationOutcome

    // Place in the tree
    /// Registers a route type for decoding and as having a destination.
    /// Renderers and coordinators call it. Unless the root's registry is
    /// permissive, a push or present of an unregistered type fails with
    /// `unregisteredRoute`, even before anything is registered.
    public func register<R: Route>(_ type: R.Type)
    /// A handle that only accepts routes of `Flow`.
    ///
    /// If this stack was declared for another flow, the handle still works
    /// and a `flowMismatch` issue is reported in development.
    public func navigator<Flow: NavigationFlow>(for flow: Flow.Type) -> FlowNavigator<Flow>

    // Defaults the app can change
}
```

### One push per tap

A fast double tap on a row calls `push` twice with the same route. While the renderer still animates a push, a second push of an equal route changes nothing and returns `.alreadyThere`, so the user lands one screen deep and goes back once. The log names the skipped push at `.debug`. A push of any other route, or of several routes at once, goes ahead as usual, and so does the same push once the first one has finished.

```swift
public enum DuplicatePushRule: Sendable, Equatable {
    /// An equal push while one is still animating changes nothing. The default.
    case skipWhileInFlight
    /// Every push goes ahead.
    case allow
}
```

The rule is on by default. Set it on a router, or on a tab container, for that flow and its children:

```swift
router.setDuplicatePushRule(.allow)
```

The core only skips while the renderer reports a push in flight, so without a renderer, as in unit tests of a coordinator, every push goes ahead.

### Settings for the whole tree

Settings that apply to the whole tree are given once, to the root router, in one `NavigationConfiguration`. Every router in the tree reads the same value through `configuration`, and none can change it, so a line in a leaf coordinator never changes the whole app. Settings for one flow, such as fallbacks and presentation defaults, stay on every router and apply to its children.

```swift
let configuration = NavigationConfiguration(
    logging: LogConfiguration.default.withMinimumLevel(.debug),
    onNavigationFailure: { failure in
        crashReporter.record(failure.description)
    }
)
let router = StackRouter(root: HomeRoute(), configuration: configuration)
```

```swift
/// The settings of a whole router tree, given once to the root router.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and handed to the root router.
public struct NavigationConfiguration: Sendable {
    /// Every setting at its default.
    public static var `default`: NavigationConfiguration { get }

    /// How the whole tree logs. Default: `LogConfiguration.default`. See <doc:EventsAndLogging>.
    public let logging: LogConfiguration
    /// The most calls queued in one main-actor turn. Default: 32. Below 1, the
    /// root router reports `invalidSetting` and uses 32. See <doc:Concurrency>.
    public let maxQueuedChanges: Int
    /// The route types known before any destination is registered, such as the
    /// ones restored state needs, and whether unregistered routes may be shown.
    /// Default: `.strict`. Tests and previews may pass `.permissive`. See <doc:Routes>.
    public let registry: RouteRegistry
    /// Called for each call anywhere in the tree that failed and could not be
    /// recovered. Default: `nil`.
    public let onNavigationFailure: (@MainActor (NavigationFailure) -> Void)?

    /// Every argument has a default.
    public init(
        logging: LogConfiguration = .default,
        maxQueuedChanges: Int = 32,
        registry: RouteRegistry = .strict,
        onNavigationFailure: (@MainActor (NavigationFailure) -> Void)? = nil
    )
}
```

`TabRouter` and `RootRouter` take the same `configuration:` argument when they are the root. Routers inside the tree, such as a tab's stack or a presented flow, are made by their parent and share its configuration.

### Building paths

Several routes of different types can be pushed or set at once with a result builder. Conditions and loops work inside it.

```swift
router.setPath {
    ProductListRoute(category: "shoes")
    ProductRoute(id: 42)
    if showReviews {
        ReviewsRoute(productID: 42)
    }
}

/// Builds a path from routes of any type.
@resultBuilder
public enum RoutePathBuilder {
    public static func buildExpression<R: Route>(_ route: R) -> [AnyRoute]
    public static func buildBlock(_ parts: [AnyRoute]...) -> [AnyRoute]
    public static func buildOptional(_ part: [AnyRoute]?) -> [AnyRoute]
    public static func buildEither(first: [AnyRoute]) -> [AnyRoute]
    public static func buildEither(second: [AnyRoute]) -> [AnyRoute]
    public static func buildArray(_ parts: [[AnyRoute]]) -> [AnyRoute]
}
```

### Transactions

```swift
router.transaction {
    $0.popToRoot()
    $0.push(ProductRoute(id: 42))
}
```

`NavigationTransaction` has the same methods as the router. They apply to a working copy, which becomes the state when the closure returns. Each step returns its own outcome, and after a failed step the rest are skipped.

```swift
/// Several navigation changes applied as one.
@MainActor
public struct NavigationTransaction {
    // push, push { }, pop, popTo, popTo(_:where:), popToRoot, setPath { },
    // present, dismiss, dismissAll and dismissFlow, as on the router,
    // each with the same `else:` fallback argument.

    /// The transaction on the presented flow, as it is so far.
    public var presented: NavigationTransaction? { get }

    /// Selects a tab, when the transaction's router is a tab container.
    @discardableResult public func select<Tab: NavigationTab>(
        _ tab: Tab,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// The transaction on one tab's stack.
    public func router<Tab: NavigationTab>(for tab: Tab) -> NavigationTransaction
}
```

The tab methods are generic, so name the tab type once: `$0.select(MainTab.shop)`.

### Outcomes

```swift
/// What a navigation call did.
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public enum NavigationOutcome: NavigationRecord {
    /// The call did what it says.
    case applied
    /// The state already matched. Nothing changed and nothing is reported.
    case alreadyThere
    /// The call arrived while another change was being applied. It runs
    /// right after, in order. A failure is reported as an issue when it runs.
    case queued
    /// The navigator's flow is gone, so the call did nothing.
    case ignored
    /// The call failed, and its fallback succeeded.
    case recovered(NavigationIssue, by: NavigationFallback)
    /// The call failed and no fallback succeeded. The state is unchanged.
    case failed(NavigationFailure)

    /// Whether the call changed the state: `applied`, or `recovered`
    /// because its fallback ran. `false` for every other outcome.
    public var didChange: Bool { get }
    /// The failure, or `nil` for any other outcome.
    public var failure: NavigationFailure? { get }
}
```

Most code ignores the outcome. Code that needs to know asks one question instead of switching over every case:

```swift
if router.popTo(CheckoutRoute.self).failure != nil {
    showCheckoutExpired()
}

if router.present(OrderRoute(id: id), else: .replacePresentation).didChange {
    analytics.track(.orderOpened)
}
```

### Issues, fallbacks and failures

A call that can only be checked at run time never crashes the app. It reports a `NavigationIssue` with the file and line of the call, then runs one fallback. The fallback is chosen in this order:

1. the call's own `else:` argument, which every navigation call takes: on routers, navigators, coordinators and transaction steps (default `nil`, meaning "use the policy")
2. the router's `FallbackPolicy`
3. the built-in default for that kind of issue

```swift
router.popTo(HomeRoute.self, else: .popToRoot)        // for one call
router.setFallback(.popToRoot, for: .routeNotInPath)   // for this flow and its children
```

The built-in defaults change nothing unless the intent is clear. Popping more routes than the path holds pops to root. Every other kind defaults to `.none`. A fallback runs once, inside the same change as the call. If it fails too, the call is rolled back and reported as a `NavigationFailure`.

```swift
/// A navigation call that could not be done as asked.
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public struct NavigationIssue: NavigationRecord {
    /// Conformances:
    /// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
    /// - `Hashable`, because it is the key of `FallbackPolicy`.
    public enum Kind: Sendable, Hashable {
        case routeNotInPath
        case emptyPath
        case notEnoughRoutes
        case unregisteredRoute
        case unknownTab
        case alreadyPresenting
        case notPresented
        case noRouterInScope
        case flowMismatch
        case denied
        case fallbackFailed
        case reentrantLoop
        case invalidSetting
        case rendererMismatch
    }
    /// What went wrong.
    public let kind: Kind
    /// The flow the call was made on.
    public let flow: FlowID
    /// What went wrong and how to fix it.
    public let message: String
    /// The file of the call.
    public let file: StaticString
    /// The line of the call.
    public let line: UInt

    /// The file name and line, such as `ShopCoordinator.swift:42`.
    public var callSite: String { get }
}

/// What to do when a call fails.
///
/// Two `custom` fallbacks are equal when their names are equal. The name
/// also appears in logs and outcomes.
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public enum NavigationFallback: NavigationRecord {
    /// Do nothing. The state stays as it was.
    case none
    /// Pop the stack to its root screen. On a tab container, pops the
    /// selected tab's stack.
    case popToRoot
    /// For `popTo` a route value: push it instead.
    case push
    /// Dismiss everything presented over this flow, including over its tabs.
    case dismissAll
    /// Dismisses everything and pops the root stack to its root screen.
    case resetToRoot
    /// For `present` while a flow is presented: dismiss it and everything
    /// above it, then present, in one change. Fails on any other call.
    case replacePresentation
    /// Run your own change. The name appears in logs and outcomes.
    case custom(
        _ name: String,
        @MainActor @Sendable (NavigationTransaction, NavigationIssue) -> Void
    )
}

/// Fallbacks by issue kind, inherited by child routers.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct FallbackPolicy: Sendable {
    public init()

    public subscript(kind: NavigationIssue.Kind) -> NavigationFallback? { get set }
}

/// A call whose fallback also failed.
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public struct NavigationFailure: NavigationRecord {
    /// Why the call failed.
    public let issue: NavigationIssue
    /// The fallback that ran and failed, or `nil` when no fallback ran.
    public let fallback: NavigationFallback?
    /// Why the fallback failed too, or `nil` when no fallback ran.
    public let fallbackIssue: NavigationIssue?
}

extension NavigationFallback {
    /// The built-in default: `.popToRoot` for `notEnoughRoutes`, `.none` otherwise.
    public static func builtIn(for kind: NavigationIssue.Kind) -> NavigationFallback
}

extension NavigationOutcome {
    /// The issue a `.recovered` call recovered from, or `nil`.
    public var recoveredIssue: NavigationIssue? { get }
}
```

A call that fails and can't be recovered reaches the tree's `onNavigationFailure` handler once, set in the root's `NavigationConfiguration` (see "Settings for the whole tree" above).

Inside a transaction, each step takes its own `else:` and uses the same order. A step whose fallback succeeds counts as recovered, and the transaction's outcome is the first recovery. A step that still fails rolls back the whole transaction. A fallback's own steps never run another fallback.

### Handles for views and view models

A handle navigates a router but owns nothing. View models take one and import only `WaypointCore`, so they can be tested with a real router on Linux.

```swift
/// Navigates a stack with any route.
@MainActor
public struct StackNavigator {
    /// Whether this navigator's flow is still in the tree. When it's gone,
    /// every call returns `.ignored`. See <doc:Concurrency>.
    public var isActive: Bool { get }

    /// Pushes a route onto the stack.
    @discardableResult public func push<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
    /// Pops `count` screens.
    @discardableResult public func pop(
        count: Int = 1,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
    /// Pops back to the last screen showing this route.
    @discardableResult public func popTo<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
    /// Pops back to the stack's root screen.
    @discardableResult public func popToRoot(
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
    /// Presents a route over this flow.
    @discardableResult public func present<R: Route>(
        _ route: R,
        style: PresentationStyle = .sheet,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
    /// Dismisses the flow this navigator belongs to.
    @discardableResult public func dismissFlow(
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
}

/// Navigates a stack with the routes of one flow only.
///
/// Conformances:
/// - `Flow: NavigationFlow`: the flow whose routes are accepted.
@MainActor
public struct FlowNavigator<Flow: NavigationFlow> {
    /// Whether this navigator's flow is still in the tree.
    public var isActive: Bool { get }
    /// The same stack with any route. Visible in code review on purpose.
    public var unscoped: StackNavigator { get }

    /// Pushes a route of this flow.
    @discardableResult public func push<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome where R.Flow == Flow
    /// Pops back to the last screen showing this route of this flow.
    @discardableResult public func popTo<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome where R.Flow == Flow
    // pop, popToRoot, present and dismissFlow as on StackNavigator
}
```

```swift
@Observable @MainActor
final class ProductModel {
    private let navigation: FlowNavigator<ShopFlow>

    init(navigation: FlowNavigator<ShopFlow>) {
        self.navigation = navigation
    }

    func buy() {
        navigation.push(CartRoute())
    }
}
```
