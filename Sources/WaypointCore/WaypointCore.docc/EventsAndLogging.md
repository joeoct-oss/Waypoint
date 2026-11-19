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
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
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
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
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
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events
///   and test failures.
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
    public func onEvents(
        _ handler: @escaping @MainActor ([NavigationEvent]) -> Void
    ) -> ObservationToken

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
    public static let navigation: LogCategory
    public static let presentation: LogCategory
    public static let tabs: LogCategory
    public static let flows: LogCategory
    public static let links: LogCategory
    public static let restoration: LogCategory
    public static let renderer: LogCategory
    public static let issues: LogCategory

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
    public let usesDefaultHandler: Bool      // true when no handler was given
    public let minimumLevel: LogLevel        // default .notice
    public let categories: Set<LogCategory>? // nil: all
    public let revealsPrivateValues: Bool    // default false
    public let format: LogFormat             // default .readable
    public let usesSymbols: Bool             // default true
    public let treeLogging: TreeLogging      // default .off

    public init(
        handler: (any LogHandler)? = nil,  // nil: the platform's default, see below
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
    /// One line per change for people reading a console: the action, then the stack. The default.
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
let logging = LogConfiguration(minimumLevel: .debug, revealsPrivateValues: true)
#else
let logging = LogConfiguration.default
#endif
let root = RootRouter(AppRoot.login, configuration: NavigationConfiguration(logging: logging))
```

A configuration made without a handler uses the platform's default (`usesDefaultHandler` is `true`). `WaypointCore` on its own logs nowhere, so tests and command-line tools stay quiet. The SwiftUI and UIKit renderers make the default the unified log: before a renderer draws a tree whose configuration has no handler, it writes the whole tree to one shared `OSLogHandler`. A handler you give is always kept, and `.disabled` turns logging off in renderers too. Any handler works, such as one that writes to a file or a test handler that records lines.

#### The unified log and signposts

`OSLogHandler` writes each line to Apple's unified log, one `Logger` category per `LogCategory`, built once, under one subsystem. The subsystem defaults to the app's bundle identifier plus `.waypoint`, such as `com.example.shop.waypoint`. Levels map one to one, with `.notice` written as the log's default level. Each line is one public string, because Waypoint already redacted it, so Console's "show private data" profile can't reveal more: turn on `revealsPrivateValues` in debug builds instead. The handler and `LogConfiguration.osLog` come with `import Waypoint` and `import WaypointUIKit`; there is no separate product to add.

```swift
// WaypointOSLog, re-exported by Waypoint and WaypointUIKit. Apple platforms only.

/// Conformances:
/// - `LogHandler`, so a router tree can write to it.
public struct OSLogHandler: LogHandler {
    public static var defaultSubsystem: String { get } // bundle identifier + ".waypoint"

    public let subsystem: String

    public init(subsystem: String = OSLogHandler.defaultSubsystem)
}

extension LogConfiguration {
    public static func osLog(
        subsystem: String = OSLogHandler.defaultSubsystem,
        minimumLevel: LogLevel = .notice,
        revealsPrivateValues: Bool = false
    ) -> LogConfiguration
}
```

You need `osLog` only to change the subsystem or to write the choice down; the renderers already use the unified log by default. A debug build that wants everything:

```swift
#if DEBUG
let logging = LogConfiguration.osLog(minimumLevel: .debug, revealsPrivateValues: true)
#else
let logging = LogConfiguration.osLog()
#endif
```

Lines show in Xcode's console and in Console.app, where you can filter by subsystem and category. From a terminal, debug and info lines need `--level debug`:

```text
log stream --level debug --predicate 'subsystem == "com.example.shop.waypoint"'
log stream --level debug --predicate 'subsystem == "com.example.shop.waypoint" AND category == "issues"'
```

Each `LogInterval` becomes an `OSSignposter` interval in its category, so it shows on the os_signpost track in Instruments. Waypoint measures:

| Interval | Category | From | To |
| --- | --- | --- | --- |
| `transaction` | `navigation` | a call starts applying | it is committed or rolled back |
| `push` | `renderer` | the stack starts animating a push | the push finishes, or a newer push replaces it |

Deep link and restore intervals come with those features. Signpost names must be fixed strings, so an interval with another name, such as one an add-on measures, is drawn as `interval` with its name in the message.

Issues a SwiftUI property wrapper finds with no router above it, such as `noRouterInScope`, go to the same default subsystem in the `issues` category as faults.

Every message is built only after the level, the category and the handler's `isEnabled(level:category:)` all agree, in that order, so a disabled line costs one comparison.

#### The readable format

By default each change is one line, in columns: `Waypoint`, the flow, a verb, what changed, then `│` and the stack the flow shows after the call. You read what happened and where you are on the same line. Routes read as words, so `ProductListRoute` prints as "Product list". Fields listed in `publicLogFields` show their values, and private fields fold into `…`. With `revealsPrivateValues` on, every value shows, in the change lines and in issue messages.

```text
Waypoint  tabs       tab      home → shop              │ root
Waypoint  shop       push     Product list (…)         │ root › Product list (…)
Waypoint  shop       push     Product (id: 42, …)      │ root › Product list (…) › Product (id: 42, …)
Waypoint  shop       recover  can't go back to a screen that isn't in the stack
                              Cart is not in the path [Product list (…) › Product (id: 42, …)]. Check contains(_:) first, or handle the .failed outcome.
                              at ShopCoordinator.swift:28
Waypoint  shop       back     Product list (…) › Product (id: 42, …), by fallback │ root
Waypoint  shop       same     already there (ShopCoordinator.swift:30)
Waypoint  shop       skip     Product (id: 42, …) is still being pushed (ProductListView.swift:24)
Waypoint  tabs       present  sheet checkout           │ Checkout (…)
Waypoint  shop       queue    waits for the current change to end (CartObserver.swift:36)
Waypoint  checkout   ignore   this flow is closed (AddressView.swift:45)
Waypoint  tabs       dismiss  checkout                 │ root › Product list (…) › Product (id: 42, …)
Waypoint  shop       back     Product (id: 42, …), by user │ root › Product list (…)
```

| Verb | Meaning | Verb | Meaning |
| --- | --- | --- | --- |
| `push` | routes pushed | `recover` | an issue a fallback recovered |
| `back` | routes closed by going back | `fail` | a failed call |
| `set` | the stack was set | `same` | nothing changed |
| `present` | a flow was presented | `skip` | a push skipped while the same one runs |
| `dismiss` | a flow was dismissed | `queue` | a call queued behind a change |
| `tab` | a tab was selected | `hold` | a change held until a transition ends |
| `stack` | the full stack, with `.changedStacks` | `ignore` | a call on a closed flow |

The stack starts at `root`, the stack's first screen, or at its root route's name when the router was made with one. A stack more than four routes deep keeps the root, the first route and the last two, with `…` between them and its depth at the end, such as `root › Product (id: 2) › … › Product (id: 5) › Product (id: 6) (5)`; `debugTree()` always prints it in full. `, by user` marks a change the user made on the screen, such as a swipe back, and `, by fallback` a change a fallback made. A call that changes the stack more than once, such as a recovered call, shows the stack after the whole call on each line. An issue is written before the change its fallback made, so the cause reads first. `usesSymbols: false` writes `>`, `|` and `->` instead of `›`, `│` and `→`, for consoles that can't show them.

To see only Waypoint's lines in Xcode's console, filter on `subsystem:` followed by your bundle identifier and `.waypoint`. The other lines in the console come from the system frameworks.

#### The navigation tree

`debugTree()` prints the whole tree at any time, from any router in it:

```text
tabs               home · [shop] · profile
├ home             root
├ shop             root › Product (…)
│ └ sheet settings Settings › Home
└ profile          root
```

`treeLogging` adds it to the log after each change: `.changedStacks` writes one more line per changed stack, in full, such as `Waypoint  shop       stack    root › Product list (…) › Product (id: 42, …)`, and `.wholeTree` writes the tree above. Change lines already end with the stack, so most apps leave it off.

#### The structured format

`format: .structured` writes the stable `NavigationDescribable` lines instead, for tools that parse logs. See <doc:Descriptions>.

| What | Level | Category | Structured example |
| --- | --- | --- | --- |
| A change was applied | `.info` | `navigation`, `presentation` or `tabs` | `pushed [ProductRoute(id: <private>)] flow=main` |
| A change made by a fallback | `.info` | as above | `popped [HomeRoute] flow=main origin=fallback` |
| A change the user made directly, such as a swipe back | `.info` | as above | `popped [ProductRoute(id: <private>)] flow=main origin=user` |
| A presentation | `.info` | `presentation` | `presented sheet SettingsRoute flow=settings presenter=main` |
| A call changed nothing | `.debug` | `navigation` | `alreadyThere flow=main at=ShopCoordinator.swift:42` |
| A push skipped because the same route is still being pushed | `.debug` | `navigation` | `alreadyThere flow=main skippedPush=ProductRoute(id: <private>) at=ProductListView.swift:24` |
| A call was queued behind a change | `.debug` | `navigation` | `reentrantChange flow=main at=ShopCoordinator.swift:42` |
| A call on a router that left the tree | `.debug` | `navigation` | `staleNavigator flow=settings at=SettingsView.swift:18` |
| A call recovered by a fallback | `.error` | `issues` | `notEnoughRoutes flow=main at=ShopCoordinator.swift:42`, then the message |
| A call failed | `.fault` | `issues` | `routeNotInPath flow=main at=ShopCoordinator.swift:42`, then the message |
| A route type problem at registration | `.error` | `issues` | `invalidRouteKey key=""` |
| A changed stack, with `.changedStacks` | `.info` | `navigation` | `stack flow=main path=[HomeRoute]` |
| A change the screen holds until a transition ends, on iOS 17 | `.debug` | `renderer` | `heldChange flow=main wait=450ms` |

Each transaction is also one `LogInterval` named `transaction` in the `navigation` category, begun and ended even when the transaction fails, and each push the screen animates is one named `push` in the `renderer` category, so a handler can draw them as signposts. Intervals are measured only when their category is enabled at the minimum level.

Privacy needs no separate log type: in both formats, route fields stay hidden unless they are listed in `publicLogFields` or `revealsPrivateValues` is on.

### Screen tracking for analytics

The router tree already knows the user's journey: which screen is showing, where the user came from and which flow they are in. A journey layer turns that into analytics-ready events that you forward to your own analytics service. Waypoint links no analytics SDK and sends nothing off the device. It is not available yet, and its API will be documented in its own article.
