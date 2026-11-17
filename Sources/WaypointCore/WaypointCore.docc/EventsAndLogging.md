# Events and logging

See what changed, where it came from, and why a call did not do what you asked.

## Overview

Every change to the navigation state produces a `NavigationEvent`. Events come from router state, never from view lifecycle callbacks like `onAppear`, so they match what is really on screen in both renderers.

```swift
router.debugTree()
// root (main)
// └ tabs: [home, *shop, profile]
//   └ shop: ProductListRoute, ProductRoute(id: 42)
//     └ sheet: FilterRoute
```

### Events

```swift
/// One applied change, with where it came from.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationEvent: Sendable, Equatable, NavigationDescribable {
    /// The flow that changed.
    public let flow: FlowID
    /// What changed.
    public let change: NavigationChange
    /// What caused the change.
    public let origin: NavigationOrigin
    /// Changes made in one transaction share an ID.
    public let transaction: TransactionID
}

/// Who asked for a change.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public enum NavigationOrigin: Sendable, Equatable, NavigationDescribable {
    /// App code called a router or a handle.
    case app
    /// The user swiped back, dragged a sheet down or tapped a tab.
    case user
    /// An incoming link.
    case deepLink
    /// Restoring saved state.
    case restoration
    /// A fallback ran because the call that was asked for failed.
    case fallback
}

/// Conformances:
/// - `Hashable`, to group the events of one transaction.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct TransactionID: Hashable, Sendable, NavigationDescribable { }
```

### Observers

An observer gets every event in order, synchronously, after each change. Use it for logs, analytics and tests. Observers added to a router see that router and everything below it.

```swift
/// Receives navigation events and issues.
///
/// Conformances:
/// - `AnyObject`, because routers keep it until its token is cancelled.
@MainActor
public protocol NavigationObserver: AnyObject {
    func navigation(didApply events: [NavigationEvent])
    func navigation(didReport issue: NavigationIssue)
}

extension NavigationObserver {
    // Both methods have empty default implementations.
}

extension StackRouter {   // also on TabRouter and RootRouter
    /// Adds an observer until the token is released or cancelled.
    @discardableResult
    public func addObserver(_ observer: some NavigationObserver) -> ObservationToken

    /// A closure observer, for one-liners.
    @discardableResult
    public func onEvents(_ handler: @escaping @MainActor ([NavigationEvent]) -> Void) -> ObservationToken

    /// A readable dump of this router and everything below it.
    public func debugTree() -> String
}

/// Conformances:
/// - `Sendable`, so it can be stored in any type and cancelled from anywhere.
public final class ObservationToken: Sendable {
    public func cancel()
}
```

An `AsyncStream` of events is not available yet. Observers cover the same needs.

### Seeing the whole tree

An event carries only the change, which keeps every change fast and every log short. Observers run right after each transaction, so an observer that wants the whole tree reads it then:

```swift
#if DEBUG
root.onEvents { _ in
    print(root.debugTree())   // the tree after this transaction
}
#endif
```

Use `snapshot()` instead of `debugTree()` when you want a value to compare or save. The tree before a transaction is the one the previous call saw.

### Diagnostic logging

Waypoint logs what it does and why, at levels you choose. Logging is on at `.notice` by default, so problems show up and normal changes stay quiet. On Apple platforms it goes to the unified log. Route values are private in logs unless you mark fields as public.

```swift
/// Conformances:
/// - `Int` raw value: orders the levels.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Comparable`, so levels can be compared, as in `level >= .notice`.
public enum LogLevel: Int, Sendable, Comparable {
    case debug
    case info
    case notice
    case error
    case fault
}

/// Conformances:
/// - `Hashable`, so categories can be kept in a set.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
public struct LogCategory: Hashable, Sendable {
    public init(_ name: String)
    public static let navigation, presentation, tabs, flows, links, restoration, renderer, issues: LogCategory
}

/// Where log messages go.
///
/// Conformances:
/// - `Sendable`, because messages can be written from any thread.
public protocol LogHandler: Sendable {
    func isEnabled(level: LogLevel, category: LogCategory) -> Bool
    func log(_ message: LogMessage)
}

/// How the whole tree logs. Set once on the root router.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct LogConfiguration: Sendable {
    public var handler: any LogHandler
    public var minimumLevel: LogLevel        // default .notice
    public var categories: Set<LogCategory>? // nil: all
    public var revealsPrivateValues: Bool    // default false
    public static var `default`: LogConfiguration { get }
    public static var disabled: LogConfiguration { get }
}

extension Route {
    /// Fields of this route that may appear in logs unredacted. Empty by default.
    public static var publicLogFields: Set<String> { get }
}
```

```swift
#if DEBUG
let root = RootRouter(AppRoot.login, logging: .init(minimumLevel: .debug, revealsPrivateValues: true))
#else
let root = RootRouter(AppRoot.login)
#endif
```

Values in log lines use their `NavigationDescribable` descriptions, so every Waypoint line has the same searchable `key=value` shape, and route fields print as `<private>` unless they are in `publicLogFields`. With `revealsPrivateValues` on, the logger uses the revealing form instead. See <doc:Descriptions>.

Issues are logged in the `issues` category: a recovered call at `.error`, and a failed call at `.fault`, each with the file and line of the call.

### Screen tracking for analytics

The router tree already knows the user's journey: which screen is showing, where the user came from and which flow they are in. A journey layer turns that into analytics-ready events that you forward to your own analytics service. Waypoint links no analytics SDK and sends nothing off the device. It is not available yet, and its API will be documented in its own article.
