# Deep links

Turn URLs, push taps and shortcuts into navigation, applied in one step.

## Overview

> Note: Draft until planning #269. The API in this article is planned, not built, and can still change when planning #269 lands.

Most links name one screen. The route declares its own URL patterns, and registering its destination registers them, so no handler is needed:

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
// - `DeepLinkable`, so it can be opened from a URL.
struct ProductRoute: Route, DeepLinkable {
    static let patterns: [URLPattern] = ["/product/:id/:slug?", "/p/:id"]

    let id: Int

    init(link: DeepLinkParameters) throws {
        id = try link.int("id")
    }
}
```

Every link source sends to one `LinkInbox`. The inbox holds a link until the app is ready, matches it, builds a plan and applies the plan to the root router in one transaction with `origin: .deepLink`.

### Routes that can be linked to

A link carries ids, so `init(link:)` builds the route from them alone. A route's `@RouteHint` field is `nil` when it comes from a link, and the screen loads by id (see <doc:Routes#Loaded-models-and-hints>).

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
let matcher = DeepLinkMatcher()
    .registering("/shop/featured/:id") { link in
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
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public struct NavigationPlan: NavigationRecord {
    public init(@NavigationPlanBuilder _ steps: () throws -> [NavigationStep]) rethrows
}

/// Steps, written as small values inside a plan.
///
/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
/// - `Root: NavigationRoot`, the app's root type.
public struct SwitchRoot<Root: NavigationRoot>: NavigationPlanStep {
    public init(_ root: Root)
}

/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
/// - `Tab: NavigationTab`, the app's tab type.
public struct SelectTab<Tab: NavigationTab>: NavigationPlanStep {
    public init(_ tab: Tab)
}

/// Conformances:
/// - `NavigationPlanStep`, so it can be written inside a `NavigationPlan`.
/// - `Tab: NavigationTab`, the app's tab type.
public struct SetPath<Tab: NavigationTab>: NavigationPlanStep {
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

    // Each returns a new matcher with one more pattern.
    public func registering<R: DeepLinkable>(_ type: R.Type) -> DeepLinkMatcher
    public func registering(
        _ pattern: URLPattern,
        _ plan: @escaping @Sendable (DeepLinkParameters) throws -> NavigationPlan
    ) -> DeepLinkMatcher
    public func plan(for url: URL) -> Result<NavigationPlan, DeepLinkError>
}

extension NavigationFallback {
    /// Applies a plan when a call fails.
    public static func plan(_ plan: NavigationPlan) -> NavigationFallback
}
```

### The link inbox

The app coordinator owns the inbox through its `links` property, and the renderers wire it up when they draw the coordinator. The app coordinator calls `markReady()` once the app can navigate, for example after it has restored the session at launch, and `markNotReady()` when it can't, for example while it resets after the user signs out. See <doc:RootSwitching>.

```swift
/// The one place every link source sends to.
@MainActor
public final class LinkInbox {
    /// Whether the app can navigate. Links wait until this is true and a root
    /// router is attached.
    public var isReady: Bool { get }

    /// Creates an inbox for the given domains, with a policy for waiting links.
    public init(domains: LinkDomains, policy: LinkPolicy = .default)

    /// Called by the app once it can navigate, for example after loading its
    /// session. Waiting links run now.
    public func markReady()

    /// Called by the app when it can't navigate, for example after logout. New
    /// links wait again.
    public func markNotReady()

    /// Opens a URL as a link, as if the system had delivered it.
    public func open(_ url: URL, source: IncomingLink.Source = .app)
    /// Opens a route directly, with no URL.
    public func open(_ route: some Route)
    /// Receives a link that an adapter has already built.
    public func receive(_ link: IncomingLink)
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
    /// The default policy: a short queue, a short expiry, and the unhandled fallback below.
    public static var `default`: LinkPolicy { get }

    /// A newer link replaces one that is waiting. Default: `.latestOnly`.
    public let pendingLimit: PendingLimit
    /// A waiting link older than this is dropped. Default: 10 minutes.
    public let expiry: Duration
    /// The same link received again within this window is ignored. Default: 2 seconds.
    public let duplicateWindow: Duration
    /// What to do with a link nothing matches. Default: `.none`.
    public let unhandled: NavigationFallback

    /// The same policy with another limit for waiting links.
    public func withPendingLimit(_ limit: PendingLimit) -> LinkPolicy
    /// The same policy with another expiry. A negative one becomes zero.
    public func withExpiry(_ expiry: Duration) -> LinkPolicy
    /// The same policy with another duplicate window. A negative one becomes zero.
    public func withDuplicateWindow(_ window: Duration) -> LinkPolicy
    /// The same policy with another fallback for links nothing matches.
    public func withUnhandled(_ fallback: NavigationFallback) -> LinkPolicy
}
```

The `Waypoint` product connects the platform entry points (URL opens, universal links, user activities, home screen quick actions) to the inbox in one line each. Push notification taps send the URL or route they carry with `source: .notification`.

### When a link can't be applied yet

A link can arrive before the app is ready, or before the user has done something the link needs, such as signing in.

- **The app is still starting.** The inbox holds every link until the app calls `markReady()` and a root router is attached. Then it applies them at once.
- **The link needs something first.** The app coordinator decides for each link whether to apply it now, hold it until a requirement the app defines (such as signing in, accepting new terms or finishing onboarding) is complete, or drop it. A held link is saved, so it still opens after the app is relaunched, and it expires after 24 hours unless the app chooses another limit.

A link that matches nothing runs the policy's `unhandled` fallback.

> Note: Holding a link until a requirement is complete is tracked in planning #351 and not designed yet, so this article doesn't show its API. Guards are not used for links: they stay for changes inside a flow, such as leaving unsaved changes.
