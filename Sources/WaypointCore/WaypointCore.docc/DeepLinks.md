# Deep links

Turn URLs, push taps and shortcuts into navigation, applied in one step.

## Overview

Most links name one screen. The route declares its own URL patterns, and registering its destination registers them, so no handler is needed:

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
// - `DeepLinkable`, so it can be opened from a URL.
struct ProductRoute: Route, DeepLinkable {
    let id: Int
    static let patterns: [URLPattern] = ["/product/:id/:slug?", "/p/:id"]

    init(link: DeepLinkParameters) throws {
        id = try link.int("id")
    }
}
```

Every link source sends to one `LinkInbox`. The inbox holds a link until the app is ready, matches it, builds a plan and applies the plan to the root router in one transaction with `origin: .deepLink`.

### Routes that can be linked to

```swift
/// A route that can be opened from a URL.
///
/// Conformances:
/// - `Route`, so it can be pushed, presented and saved.
public protocol DeepLinkable: Route {
    /// The URL paths that open this route. Hosts and schemes are set once in `LinkDomains`.
    static var patterns: [URLPattern] { get }

    /// Builds the route from the matched values.
    init(link: DeepLinkParameters) throws
}

extension DeepLinkable {
    /// A one-pattern shorthand. Implement either `pattern` or `patterns`.
    public static var pattern: URLPattern { get }
}

/// A URL path pattern, such as `"/product/:id/:slug?"`.
///
/// `:name` captures a segment, and a trailing `?` makes it optional.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Hashable`, so duplicate patterns can be found.
/// - `ExpressibleByStringLiteral`, so it can be written as a string literal.
public struct URLPattern: Sendable, Hashable, ExpressibleByStringLiteral {
    public init(_ pattern: String)

    public func match(_ url: URL) -> DeepLinkParameters?
}

/// Values captured from a URL, read with clear errors.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct DeepLinkParameters: Sendable {
    public func string(_ name: String) throws -> String
    public func int(_ name: String) throws -> Int
    public func uuid(_ name: String) throws -> UUID
    public func query(_ name: String) -> String?
}

/// Conformances:
/// - `Error`, so it can be thrown.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
public enum DeepLinkError: Error, Sendable, Equatable {
    case noMatch(URL)
    case missingParameter(String)
    case invalidParameter(name: String, value: String, expected: String)
}
```

### Plans for links that need several steps

A `NavigationPlan` is an ordered list of steps over the whole tree. It is built with a result builder, so conditions work inside it.

```swift
matcher.register("/shop/featured/:id") { link in
    NavigationPlan {
        SelectTab(MainTab.shop)
        SetPath(in: MainTab.shop) {
            ProductListRoute(category: "all")
            ProductRoute(id: try link.int("id"))
        }
    }
}
```

```swift
/// Steps over the navigation tree, applied as one transaction.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationPlan: Sendable, Equatable, NavigationDescribable {
    public init(@NavigationPlanBuilder _ steps: () throws -> [NavigationStep]) rethrows
}

/// Steps, written as small values inside a plan.
///
/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
/// - `Root: Hashable`, to compare roots.
/// - `Root: Codable`, so the current root is saved and restored.
/// - `Root: Sendable`, so root events can leave the main actor.
public struct SwitchRoot<Root: Hashable & Codable & Sendable>: NavigationPlanStep {
    public init(_ root: Root)
}

/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
public struct SelectTab<Tab: Hashable & Codable & Sendable>: NavigationPlanStep {
    public init(_ tab: Tab)
}

/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
public struct SetPath<Tab: Hashable & Codable & Sendable>: NavigationPlanStep {
    public init(in tab: Tab, @RoutePathBuilder _ routes: () throws -> [AnyRoute]) rethrows
}

/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
public struct Push: NavigationPlanStep {
    public init<R: Route>(_ route: R)
}

/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
public struct Present: NavigationPlanStep {
    public init<R: Route>(_ route: R, style: PresentationStyle = .sheet)
}

/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
public struct DismissAll: NavigationPlanStep {
    public init()
}

/// Matches URLs to plans. Registering a `DeepLinkable` destination fills it.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct DeepLinkMatcher: Sendable {
    public init()

    public mutating func register<R: DeepLinkable>(_ type: R.Type)
    public mutating func register(_ pattern: URLPattern,
                                  _ plan: @escaping @Sendable (DeepLinkParameters) throws -> NavigationPlan)
    public func plan(for url: URL) -> Result<NavigationPlan, DeepLinkError>
}

extension NavigationFallback {
    /// Applies a plan when a call fails.
    public static func plan(_ plan: NavigationPlan) -> NavigationFallback
}
```

### The link inbox

The app coordinator owns the inbox through its `links` property, and the renderers wire it up when they draw the coordinator. The app coordinator sets `isReady` once the app can navigate, for example after login. See <doc:RootSwitching>.

```swift
/// The one place every link source sends to.
@MainActor
public final class LinkInbox {
    public init(domains: LinkDomains, policy: LinkPolicy = .default)

    public func open(_ url: URL, source: IncomingLink.Source = .app)
    public func open(_ route: some Route)
    public func receive(_ link: IncomingLink)

    /// Set by the app once it can navigate, for example after loading its session.
    /// Links wait until this is true and a root router is attached.
    public var isReady: Bool { get set }
}

/// The hosts and schemes this app answers, set once.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct LinkDomains: Sendable {
    public init(hosts: Set<String>, schemes: Set<String> = [], trackingParameters: Set<String> = [])
}

/// How the inbox treats links. Every value has a default you can change.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct LinkPolicy: Sendable {
    /// A newer link replaces one that is waiting. Default: `.latestOnly`.
    public var pendingLimit: PendingLimit
    /// A waiting link older than this is dropped. Default: 10 minutes.
    public var expiry: Duration
    /// The same link received again within this window is ignored. Default: 2 seconds.
    public var duplicateWindow: Duration
    /// What to do with a link nothing matches. Default: `.none`.
    public var unhandled: NavigationFallback
    public static var `default`: LinkPolicy { get }
}
```

The renderer products connect the platform entry points (URL opens, universal links, user activities, home screen quick actions) to the inbox in one line each. Push notification taps send the URL or route they carry with `source: .notification`.

### When a link can't be applied yet

If a guard redirects a link, for example to login, the plan is parked. It resumes after the redirect flow finishes, unless a newer link replaces it or it expires. A link that matches nothing runs the policy's `unhandled` fallback.
