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
public struct NavigationEvent: Sendable, Equatable {
    public let flow: FlowID
    public let change: NavigationChange
    public let origin: NavigationOrigin
    /// Changes made in one transaction share an ID.
    public let transaction: TransactionID
}

/// Who asked for a change.
public enum NavigationOrigin: Sendable, Equatable {
    /// App code called a router or a handle.
    case app
    /// The user swiped back, dragged a sheet down or tapped a tab.
    case user
    case deepLink
    case restoration
    /// A fallback ran because the call that was asked for failed.
    case fallback
}

public struct TransactionID: Hashable, Sendable { }
```

### Observers

An observer gets every event in order, synchronously, after each change. Use it for logs, analytics and tests. Observers added to a router see that router and everything below it.

```swift
/// Receives navigation events and issues.
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

public final class ObservationToken: Sendable {
    public func cancel()
}
```

An `AsyncStream` of events is not available yet. Observers cover the same needs.

### Diagnostic logging

Waypoint logs what it does and why, at levels you choose. Logging is on at `.notice` by default, so problems show up and normal changes stay quiet. On Apple platforms it goes to the unified log. Route values are private in logs unless you mark fields as public.

```swift
public enum LogLevel: Int, Sendable, Comparable { case debug, info, notice, error, fault }

public struct LogCategory: Hashable, Sendable {
    public init(_ name: String)
    public static let navigation, presentation, tabs, flows, links, restoration, renderer, issues: LogCategory
}

/// Where log messages go.
public protocol LogHandler: Sendable {
    func isEnabled(level: LogLevel, category: LogCategory) -> Bool
    func log(_ message: LogMessage)
}

/// How the whole tree logs. Set once on the root router.
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

Issues are logged in the `issues` category: a recovered call at `.error`, and a failed call at `.fault`, each with the file and line of the call.

### Screen tracking for analytics

The router tree already knows the user's journey: which screen is showing, where the user came from and which flow they are in. A journey layer turns that into analytics-ready events that you forward to your own analytics service. Waypoint links no analytics SDK and sends nothing off the device. It is not available yet, and its API will be documented in its own article.
