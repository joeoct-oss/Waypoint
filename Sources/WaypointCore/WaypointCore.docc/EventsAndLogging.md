# Events and logging

See what changed, where it came from, and why a call did not do what you asked.

## Overview

> Note: The logging part of this article is built. The events part is a draft until #23 and can still change when it lands.

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
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in logs.
public struct NavigationEvent: NavigationRecord {
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
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in logs.
public enum NavigationOrigin: NavigationRecord {
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

    /// The whole tree, one flow per line. See "The navigation tree" below.
    public func debugTree(revealingPrivateValues: Bool = false) -> String
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
    public static let navigation, presentation, tabs, flows, links, restoration, renderer, issues: LogCategory

    public init(_ name: String)
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
    public static var `default`: LogConfiguration { get }
    public static var disabled: LogConfiguration { get }

    public let handler: any LogHandler
    public let minimumLevel: LogLevel        // default .notice
    public let categories: Set<LogCategory>? // nil: all
    public let revealsPrivateValues: Bool    // default false
    public let format: LogFormat             // default .readable
    public let usesSymbols: Bool             // default true
    public let treeLogging: TreeLogging      // default .off

    public init(
        handler: any LogHandler = DisabledLogHandler(),
        minimumLevel: LogLevel = .notice,
        categories: Set<LogCategory>? = nil,
        revealsPrivateValues: Bool = false,
        format: LogFormat = .readable,
        usesSymbols: Bool = true,
        treeLogging: TreeLogging = .off
    )

    // Each returns a new configuration with one value changed.
    public func withHandler(_ handler: any LogHandler) -> LogConfiguration
    public func withMinimumLevel(_ level: LogLevel) -> LogConfiguration
    public func withCategories(_ categories: Set<LogCategory>?) -> LogConfiguration
    public func withPrivateValuesRevealed(_ reveals: Bool) -> LogConfiguration
    public func withFormat(_ format: LogFormat) -> LogConfiguration
    public func withSymbols(_ usesSymbols: Bool) -> LogConfiguration
    public func withTreeLogging(_ treeLogging: TreeLogging) -> LogConfiguration

    public func isEnabled(level: LogLevel, category: LogCategory) -> Bool
    public func measuresIntervals(in category: LogCategory) -> Bool
}

/// How log lines are written.
///
/// Conformances:
/// - `Sendable`, so a configuration that holds it can be shared with the whole tree.
/// - `Equatable`, so tests can compare formats.
public enum LogFormat: Sendable, Equatable {
    /// Sentences for people reading a console, with friendly route names. The default.
    case readable
    /// The stable `key=value` lines of `NavigationDescribable`, for tools that parse logs.
    case structured
}

/// Which part of the navigation tree is logged after each change, at `.info`.
///
/// Conformances:
/// - `Sendable`, so a configuration that holds it can be shared with the whole tree.
/// - `Equatable`, so tests can compare settings.
public enum TreeLogging: Sendable, Equatable {
    /// Nothing more than the changes. The default.
    case off
    /// One line with each changed stack.
    case changedStacks
    /// The whole tree, one flow per line, after every change.
    case wholeTree
}

extension StackRouter {   // also on TabRouter
    /// The whole tree this router is in, one flow per line, for printing while debugging.
    public func debugTree(revealingPrivateValues: Bool = false) -> String
}

extension Route {
    /// Fields of this route that may appear in logs unredacted. Empty by default.
    public static var publicLogFields: Set<String> { get }
}
```

Logging is set once for the whole tree, in the `NavigationConfiguration` given to the root router (see <doc:StackNavigation>). Every router reads it through `configuration.logging`, and none can change it:

```swift
#if DEBUG
let logging = LogConfiguration(minimumLevel: .debug, treeLogging: .changedStacks)
#else
let logging = LogConfiguration.default
#endif
let root = RootRouter(AppRoot.login, configuration: NavigationConfiguration(logging: logging))
```

`WaypointCore` on its own logs nowhere: its default handler is `DisabledLogHandler`. The SwiftUI and UIKit products install a unified-log handler as the default. Any handler works, such as one that writes to a file or a test handler that records lines.

Every message is built only after the level, the category and the handler's `isEnabled(level:category:)` all agree, in that order, so a disabled line costs one comparison.

#### The readable format

By default each line names the flow, then a symbol and a sentence. Routes read as words, so `ProductListRoute` prints as "Product list". Fields listed in `publicLogFields` show their values, and private fields fold into `…`. With `revealsPrivateValues` on, every value shows, in the change lines and in issue messages.

```text
tabs       ⇥ tab home → shop
shop       ▸ push Product list (…)
shop       ▸ push Product (id: 42, …)
shop       ⚠︎ recovered: can't go back to a screen that isn't in the stack
             Cart is not in the path [Product list (…) › Product (id: 42, …)]. Check contains(_:) first, or handle the .failed outcome.
             at ShopCoordinator.swift:28
shop       ◂ back to the first screen (closed Product list (…) › Product (id: 42, …)) · by fallback
shop       = already there (ShopCoordinator.swift:30)
tabs       ↑ present sheet checkout: Checkout (…)
shop       … queued until the current change ends (CartObserver.swift:36)
checkout   ∅ ignored: this flow is closed (AddressView.swift:45)
tabs       ↓ dismiss checkout
```

| Symbol | Meaning | Symbol | Meaning |
| --- | --- | --- | --- |
| `▸` | push | `⚠︎` | an issue a fallback recovered |
| `◂` | back | `✖︎` | a failed call |
| `↻` | the stack was set | `=` | nothing changed |
| `↑` | present | `…` | queued behind a change |
| `↓` | dismiss | `∅` | ignored: the flow is closed |
| `⇥` | tab selected | `≡` | the stack after a change |

`usesSymbols: false` drops the symbols and joins routes with `>` instead of `›`, for consoles that can't show them. An issue is written before the change its fallback made, so the cause reads first.

#### The navigation tree

`debugTree()` prints the whole tree at any time, from any router in it:

```text
tabs               home · [shop] · profile
├ home             first screen
├ shop             Product (…)
│ └ sheet settings Settings › Home
└ profile          first screen
```

`treeLogging` adds it to the log after each change: `.changedStacks` writes one line per changed stack, such as `shop       ≡ Product list (…) › Product (id: 42, …)`, and `.wholeTree` writes the tree above.

#### The structured format

`format: .structured` writes the stable `NavigationDescribable` lines instead, for tools that parse logs. See <doc:Descriptions>.

| What | Level | Category | Structured example |
| --- | --- | --- | --- |
| A change was applied | `.info` | `navigation`, `presentation` or `tabs` | `pushed [ProductRoute(id: <private>)] flow=main` |
| A change made by a fallback | `.info` | as above | `popped [HomeRoute] flow=main origin=fallback` |
| A change the user made directly, such as a swipe back | `.info` | as above | `popped [ProductRoute(id: <private>)] flow=main origin=user` |
| A presentation | `.info` | `presentation` | `presented sheet SettingsRoute flow=settings presenter=main` |
| A call changed nothing | `.debug` | `navigation` | `alreadyThere flow=main at=ShopCoordinator.swift:42` |
| A call was queued behind a change | `.debug` | `navigation` | `reentrantChange flow=main at=ShopCoordinator.swift:42` |
| A call on a router that left the tree | `.debug` | `navigation` | `staleNavigator flow=settings at=SettingsView.swift:18` |
| A call recovered by a fallback | `.error` | `issues` | `notEnoughRoutes flow=main at=ShopCoordinator.swift:42`, then the message |
| A call failed | `.fault` | `issues` | `routeNotInPath flow=main at=ShopCoordinator.swift:42`, then the message |
| A route type problem at registration | `.error` | `issues` | `invalidRouteKey key=""` |
| A changed stack, with `.changedStacks` | `.info` | `navigation` | `stack flow=main path=[HomeRoute]` |

Each transaction is also one `LogInterval` named `transaction` in the `navigation` category, begun and ended even when the transaction fails, so a handler can draw it as a signpost. Intervals are measured only when the `navigation` category is enabled at the minimum level.

Privacy needs no separate log type: in both formats, route fields stay hidden unless they are listed in `publicLogFields` or `revealsPrivateValues` is on.

### Screen tracking for analytics

The router tree already knows the user's journey: which screen is showing, where the user came from and which flow they are in. A journey layer turns that into analytics-ready events that you forward to your own analytics service. Waypoint links no analytics SDK and sends nothing off the device. It is not available yet, and its API will be documented in its own article.
