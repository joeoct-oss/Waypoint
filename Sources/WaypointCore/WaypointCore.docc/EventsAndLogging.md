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

/// One log line, built only after the level and category were found enabled.
///
/// Conformances:
/// - `Sendable`, so a handler can write it from any thread.
public struct LogMessage: Sendable {
    public let level: LogLevel
    public let category: LogCategory
    public let text: String       // the NavigationDescribable line, redacted unless revealing
    public let file: StaticString // the call site in your code
    public let line: UInt
}

/// A measured span, such as one transaction. Handlers may draw it as a signpost.
///
/// Conformances:
/// - `Sendable`, so a handler can keep it on any thread.
/// - `Hashable`, so a handler can match the end of an interval to its start.
public struct LogInterval: Sendable, Hashable {
    public let name: String
    public let category: LogCategory
    public let id: UInt64
}

/// Where log messages go.
///
/// Conformances:
/// - `Sendable`, because messages can be written from any thread.
public protocol LogHandler: Sendable {
    func isEnabled(level: LogLevel, category: LogCategory) -> Bool
    func log(_ message: LogMessage)
    func beginInterval(_ interval: LogInterval) // default: does nothing
    func endInterval(_ interval: LogInterval)   // default: does nothing
}

/// A handler that is never enabled, so no message is ever built.
///
/// Conformances:
/// - `LogHandler`, so it can stand in for a real handler.
public struct DisabledLogHandler: LogHandler {
    public init()
}

/// How the whole tree logs. Set once on the root router.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct LogConfiguration: Sendable {
    public init(
        handler: any LogHandler = DisabledLogHandler(),
        minimumLevel: LogLevel = .notice,
        categories: Set<LogCategory>? = nil,
        revealsPrivateValues: Bool = false
    )
    public var handler: any LogHandler
    public var minimumLevel: LogLevel        // default .notice
    public var categories: Set<LogCategory>? // nil: all
    public var revealsPrivateValues: Bool    // default false
    public static var `default`: LogConfiguration { get }
    public static var disabled: LogConfiguration { get }
    public func isEnabled(level: LogLevel, category: LogCategory) -> Bool
    public func measuresIntervals(in category: LogCategory) -> Bool
}

extension StackRouter {
    /// How this router's whole tree logs. Shared by every router in the tree.
    public var logging: LogConfiguration { get set }
}

extension TabRouter {
    /// How this router's whole tree logs. Shared by every router in the tree.
    public var logging: LogConfiguration { get set }
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

`WaypointCore` on its own logs nowhere: its default handler is `DisabledLogHandler`. The SwiftUI and UIKit products install a unified-log handler as the default. Any handler works, such as one that writes to a file or a test handler that records lines.

Every message is built only after the level, the category and the handler's `isEnabled(level:category:)` all agree, in that order, so a disabled line costs one comparison. Waypoint writes these lines:

| What | Level | Category | Example |
| --- | --- | --- | --- |
| A change was applied | `.info` | `navigation`, `presentation` or `tabs` | `pushed [ProductRoute(id: <private>)] flow=main` |
| A change made by a fallback | `.info` | as above | `popped [HomeRoute] flow=main origin=fallback` |
| A call changed nothing | `.debug` | `navigation` | `alreadyThere flow=main at=ShopCoordinator.swift:42` |
| A call was queued behind a change | `.debug` | `navigation` | `reentrantChange flow=main at=ShopCoordinator.swift:42` |
| A call on a router that left the tree | `.debug` | `navigation` | `staleNavigator flow=settings at=SettingsView.swift:18` |
| A call recovered by a fallback | `.error` | `issues` | `notEnoughRoutes flow=main at=ShopCoordinator.swift:42`, then the message |
| A call failed | `.fault` | `issues` | `routeNotInPath flow=main at=ShopCoordinator.swift:42`, then the message |
| A route type problem at registration | `.error` | `issues` | `invalidRouteKey key=""` |

Each transaction is also one `LogInterval` named `transaction` in the `navigation` category, begun and ended even when the transaction fails, so a handler can draw it as a signpost. Intervals are measured only when the `navigation` category is enabled at the minimum level.

Privacy needs no separate log type: every line is built from `NavigationDescribable` descriptions, which already print route fields as `<private>` unless they are listed in `publicLogFields`.

### Screen tracking for analytics

The router tree already knows the user's journey: which screen is showing, where the user came from and which flow they are in. A journey layer turns that into analytics-ready events that you forward to your own analytics service. Waypoint links no analytics SDK and sends nothing off the device. It is not available yet, and its API will be documented in its own article.
