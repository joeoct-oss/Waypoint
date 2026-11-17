# Routes

Name each screen with a small value type, and register it by its type.

## Overview

A route is a value that names one screen and carries its inputs. Waypoint uses one small type per screen, so adding a screen is a local change: one route type and one registration line. No central `switch` is needed.

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    let id: Int
}
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct CartRoute: Route { }

router.push(ProductRoute(id: 42))
```

Every route is `Hashable`, `Codable` and `Sendable` through the `Route` protocol. <doc:WhyTheseConformances> explains what each one is for.

Routes hold identifiers and small inputs, never models or view models. That keeps them cheap to compare, store, log and deep link into.

A small enum is still fine for a closed group of screens, such as the steps of a wizard. It is registered as one type:

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
enum CheckoutStep: Route {
    case address
    case payment
    case review
}
```

### The route protocol

```swift
/// A value that names one screen and carries its inputs.
///
/// Conforming types are usually small structs with `let` properties.
/// `Codable` is required so routes can be restored and deep linked into.
///
/// Conformances:
/// - `Hashable`, so the router can compare routes and find them in a path.
/// - `Codable`, so routes can be saved, restored and built from links.
/// - `Sendable`, so routes can be logged and tracked off the main actor.
public protocol Route: Hashable, Codable, Sendable {
    /// The flow this route belongs to.
    ///
    /// Leave it out and the route can be pushed onto any stack. Set it to
    /// restrict the route to one flow, checked by the compiler through
    /// `FlowNavigator<Flow>`.
    associatedtype Flow: NavigationFlow = AnyFlow

    /// The stable name used when this route is saved, logged or decoded.
    ///
    /// Defaults to the type name. Override it before renaming a type, so
    /// saved navigation state keeps decoding.
    static var routeKey: String { get }
}

extension Route {
    public static var routeKey: String { get }
}
```

### Scoping routes to a flow

Scoping is opt in. A route that names its flow can only be pushed through that flow's navigator, and the compiler checks it.

```swift
/// A marker for a group of screens with one job, such as checkout.
///
/// A coordinator can be its own flow type, or you can declare an empty enum.
public protocol NavigationFlow { }

/// The flow of routes that don't declare one. They can be pushed anywhere.
///
/// Conformances:
/// - `NavigationFlow`, so routes can name it as their flow.
public enum AnyFlow: NavigationFlow { }
```

```swift
// Conformances:
// - `NavigationFlow`, so routes can name it as their flow.
enum ShopFlow: NavigationFlow { }

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct CartRoute: Route {
    typealias Flow = ShopFlow
}
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct HelpRoute: Route { }   // unscoped

func checkout(_ shop: FlowNavigator<ShopFlow>) {
    shop.push(CartRoute())             // compiles
    // shop.push(HelpRoute())          // does not compile
    shop.unscoped.push(HelpRoute())    // the visible escape hatch
}
```

### Type-erased routes

Routers, state, events and snapshots hold routes of many types, so they store them as `AnyRoute`. Every public navigation method is generic, so app code works with its own types and rarely sees `AnyRoute`.

```swift
/// A route of any type, with its stable key.
///
/// Conformances:
/// - `Hashable`, so paths can be compared and searched.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `CustomStringConvertible`, for readable logs and test failures.
public struct AnyRoute: Hashable, Sendable, CustomStringConvertible {
    /// Wraps a route.
    public init<R: Route>(_ route: R)

    /// The wrapped route's `routeKey`.
    public var routeKey: String { get }

    /// The wrapped route as `R`, or `nil` if it is another type.
    public func `as`<R: Route>(_ type: R.Type) -> R?

    /// Whether the wrapped route is of type `R`.
    public func `is`<R: Route>(_ type: R.Type) -> Bool

    /// A readable description, such as `ProductRoute(id: 42)`.
    public var description: String { get }
}
```

### Decoding routes

Decoding an `AnyRoute` needs to know which concrete type a key stands for. Registering a destination for a route type also registers it for decoding, so most apps never touch the registry.

```swift
/// Maps route keys to route types, so erased routes can be encoded and decoded.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct RouteRegistry: Sendable {
    public init()

    /// Registers a route type under its `routeKey`.
    ///
    /// Registering the same type twice does nothing. Registering a different
    /// type under a key that is already taken reports `duplicateRouteKey`.
    public mutating func register<R: Route>(_ type: R.Type)

    public func encode(_ route: AnyRoute, to encoder: any Encoder) throws
    public func decode(from decoder: any Decoder) throws -> AnyRoute
}

/// Why an erased route could not be decoded.
///
/// Conformances:
/// - `Error`, so it can be thrown.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
public enum RouteDecodingError: Error, Sendable, Equatable {
    case unknownRouteKey(String)
    case invalidPayload(routeKey: String)
    case duplicateRouteKey(String)
}
```

### Registering destinations

Destinations say how each route type is shown. The renderers fill a `RouteTable` with SwiftUI views or UIKit view controllers, and tests fill it with plain values, so lookup is the same code everywhere. Apps use the renderer's `.destination(_:)` modifiers or a coordinator's destinations instead of the table itself.

```swift
/// A table of destinations keyed by route type.
///
/// `Payload` is whatever the renderer builds for a route: a view, a view
/// controller, or a test value.
public struct RouteTable<Payload> {
    public init()

    /// Registers how to build the payload for one route type.
    ///
    /// Also registers the type for decoding.
    public mutating func register<R: Route>(_ type: R.Type, _ make: @escaping (R) -> Payload)

    /// The payload for a route, or `nil` if its type is not registered.
    public func payload(for route: AnyRoute) -> Payload?

    /// Every registered route type.
    public var registeredTypes: [any Route.Type] { get }
}
```

A route with no destination never crashes the app. The router reports an `unregisteredRoute` issue with the file and line of the call. Debug builds show a "No destination for …" screen, and release builds refuse the push.
