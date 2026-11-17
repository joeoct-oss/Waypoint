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
    /// Creates a router with an empty path.
    public init()

    /// The current state. Change it only through the methods below.
    public private(set) var state: StackState

    // Pushing

    /// Pushes one route.
    @discardableResult public func push<R: Route>(_ route: R) -> NavigationOutcome

    /// Pushes several routes as one change, with one animation.
    @discardableResult public func push(@RoutePathBuilder _ routes: () -> [AnyRoute]) -> NavigationOutcome

    // Popping

    /// Pops `count` routes. Popping more than the path holds pops to the root
    /// and returns `.recovered`.
    @discardableResult public func pop(count: Int = 1) -> NavigationOutcome

    /// Pops to the last occurrence of `route`.
    ///
    /// Returns `.alreadyThere` if it is on top. If the route is the stack's
    /// root screen, this pops to root.
    @discardableResult public func popTo<R: Route>(_ route: R) -> NavigationOutcome

    /// Pops to the last route of type `R` that matches `predicate`.
    @discardableResult public func popTo<R: Route>(_ type: R.Type, where predicate: (R) -> Bool = { _ in true }) -> NavigationOutcome

    /// Empties the path, showing the root screen.
    @discardableResult public func popToRoot() -> NavigationOutcome

    // Replacing

    /// Replaces the whole path as one change.
    @discardableResult public func setPath(@RoutePathBuilder _ routes: () -> [AnyRoute]) -> NavigationOutcome

    // Reading

    public func contains<R: Route>(_ route: R) -> Bool
    public func last<R: Route>(_ type: R.Type) -> R?

    // Several changes as one

    /// Applies several changes as one: the state changes once, the renderer
    /// draws once, and observers get one batch.
    ///
    /// If any step ends `.failed`, the whole transaction is rolled back.
    @discardableResult public func transaction(_ body: (inout NavigationTransaction) -> Void) -> NavigationOutcome

    // Place in the tree

    public var flowID: FlowID { get }
    public var parent: (any NavigationRouter)? { get }

    // Handles

    /// A handle that can navigate this stack with any route.
    public var navigator: StackNavigator { get }

    /// A handle that only accepts routes of `Flow`.
    ///
    /// If this stack was declared for another flow, the handle still works
    /// and a `flowMismatch` issue is reported in development.
    public func navigator<Flow: NavigationFlow>(for flow: Flow.Type) -> FlowNavigator<Flow>

    // Defaults the app can change

    /// What to do when a call fails and passes no fallback. Children inherit it.
    public var fallbackPolicy: FallbackPolicy { get set }
}
```

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

`NavigationTransaction` has the same methods as the router. They apply to a working copy, which becomes the state when the closure returns.

### Outcomes

```swift
/// What a navigation call did.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public enum NavigationOutcome: Sendable, Equatable, NavigationDescribable {
    /// The call did what it says.
    case applied
    /// The state already matched. Nothing changed and nothing is reported.
    case alreadyThere
    /// The call failed, and its fallback succeeded.
    case recovered(NavigationIssue, by: NavigationFallback)
    /// The call failed and no fallback succeeded. The state is unchanged.
    case failed(NavigationFailure)
}
```

Most code ignores the outcome. Code that needs to know can check it:

```swift
if case .failed = router.popTo(CheckoutRoute.self) {
    showCheckoutExpired()
}
```

### Issues, fallbacks and failures

A call that can only be checked at run time never crashes the app. It reports a `NavigationIssue` with the file and line of the call, then runs one fallback. The fallback is chosen in this order:

1. the call's own `else:` argument
2. the router's `FallbackPolicy`
3. the built-in default for that kind of issue

```swift
router.popTo(HomeRoute.self, else: .popToRoot)        // for one call
router.fallbackPolicy[.routeNotInPath] = .popToRoot   // for this flow and its children
```

The built-in defaults change nothing unless the intent is clear. Popping more routes than the path holds pops to root. Every other kind defaults to `.none`. A fallback runs once, inside the same change as the call. If it fails too, the call is rolled back and reported as a `NavigationFailure`.

```swift
/// A navigation call that could not be done as asked.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationIssue: Sendable, Equatable, NavigationDescribable {
    /// Conformances:
    /// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
    /// - `Hashable`, because it is the key of `FallbackPolicy`.
    public enum Kind: Sendable, Hashable {
        case routeNotInPath
        case emptyPath
        case unregisteredRoute
        case unknownTab
        case alreadyPresenting
        case noRouterInScope
        case flowMismatch
        case denied
        case fallbackFailed
    }
    public let kind: Kind
    public let flow: FlowID
    /// What went wrong and how to fix it.
    public let message: String
    public let file: StaticString
    public let line: UInt
}

/// What to do when a call fails.
///
/// Two `custom` fallbacks are equal when their names are equal. The name
/// also appears in logs and outcomes.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so outcomes that carry it can be compared in tests.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public enum NavigationFallback: Sendable, Equatable, NavigationDescribable {
    case none
    case popToRoot
    /// For `popTo` a route value: push it instead.
    case push
    case dismissAll
    /// Dismisses everything and pops the root stack to its root screen.
    case resetToRoot
    case custom(_ name: String, @MainActor @Sendable (inout NavigationTransaction, NavigationIssue) -> Void)
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
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationFailure: Sendable, Equatable, NavigationDescribable {
    public let issue: NavigationIssue
    public let fallbackIssue: NavigationIssue?
}
```

### Handles for views and view models

A handle navigates a router but owns nothing. View models take one and import only `WaypointCore`, so they can be tested with a real router on Linux.

```swift
/// Navigates a stack with any route.
@MainActor
public struct StackNavigator {
    @discardableResult public func push<R: Route>(_ route: R) -> NavigationOutcome
    @discardableResult public func pop(count: Int = 1) -> NavigationOutcome
    @discardableResult public func popTo<R: Route>(_ route: R) -> NavigationOutcome
    @discardableResult public func popToRoot() -> NavigationOutcome
    @discardableResult public func present<R: Route>(_ route: R, style: PresentationStyle = .sheet) -> NavigationOutcome
    @discardableResult public func dismissFlow() -> NavigationOutcome
}

/// Navigates a stack with the routes of one flow only.
///
/// Conformances:
/// - `Flow: NavigationFlow`: the flow whose routes are accepted.
@MainActor
public struct FlowNavigator<Flow: NavigationFlow> {
    @discardableResult public func push<R: Route>(_ route: R) -> NavigationOutcome where R.Flow == Flow
    @discardableResult public func popTo<R: Route>(_ route: R) -> NavigationOutcome where R.Flow == Flow
    // pop, popToRoot, present and dismissFlow as on StackNavigator

    /// The same stack with any route. Visible in code review on purpose.
    public var unscoped: StackNavigator { get }
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
