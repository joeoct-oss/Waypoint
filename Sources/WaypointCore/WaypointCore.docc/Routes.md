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

Routes hold identifiers and small inputs, never models or view models. That keeps them cheap to compare, store, log and deep link into. <doc:Routes#Loaded-models-and-hints> shows how a screen gets its model.

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
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
public protocol Route: NavigationValue {
    /// The flow this route belongs to.
    ///
    /// Leave it out and the route can be pushed onto any stack. Set it to
    /// restrict the route to one flow, checked by the compiler through
    /// `FlowNavigator<Flow>`.
    associatedtype Flow: NavigationFlow = AnyFlow

    /// Keys this route type had before it was renamed or moved, so state
    /// saved by older versions still decodes. Default: none.
    static var formerRouteKeys: [RouteKey] { get }

    /// Fields of this route that may appear in logs and descriptions
    /// unredacted. Default: none. For an enum case with one unlabelled
    /// value, list the case name.
    static var publicLogFields: Set<String> { get }
}

extension Route {
    /// This route type's key, from its module and type name.
    public static var routeKey: RouteKey { get }
}
```

### Loaded models and hints

A route carries identity, and the coordinator supplies the model. The destination builds the screen's model from the route's id, and the model asks the app's store or cache for the data:

```swift
.destination(ProductRoute.self) { route in
    ProductView(
        model: ProductModel(
            id: route.id,
            store: store
        )
    )
}
```

This is what makes every screen work from a link and after a restore, where only the id is known. Callbacks don't go in routes either: a screen reports its outputs, such as "Buy tapped on product 42", and the coordinator decides what comes next.

When a list already loaded the product, a hint lets the next screen show it at once. Mark one optional field `@RouteHint` and fill it when you push:

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    let id: Product.ID

    @RouteHint
    var preview: Product?
}

router.push(
    ProductRoute(
        id: product.id,
        preview: product
    )
)
```

The screen shows `preview` for its first frame, then refreshes by id. A hint is not part of the route:

- **Never saved.** Encoding writes nothing for it, so saved state holds `{"id": 42}`. A restored route, and a route built from a link, has `nil`.
- **Never compared.** Two routes with the same id are equal and hash the same, whatever their hints hold. `popTo`, `contains` and duplicate checks see one route.
- **Never described.** Logs, events and test failures leave the field out, even when private values are revealed or the field is listed in `publicLogFields`.

So a hint is a first frame only, and the screen must work without it. Don't put state the screen needs in a hint; it is gone after a restore. The hinted value needs only `Sendable`, not `Hashable` or `Codable`, so a plain model struct works. Leave the field out when you push and it is `nil`: `ProductRoute(id: 42)`.

```swift
/// A value a route carries for its screen's first frame only.
///
/// Conformances:
/// - `Sendable`, because routes cross actors.
/// - `Hashable`, so a hinted route still compares and hashes by its identity only.
/// - `Codable`, so a hinted route still saves; the hint itself is never written.
/// - `Value: Sendable`, so a route that holds the hint stays `Sendable`.
@propertyWrapper
public struct RouteHint<Value: Sendable>: Sendable, Hashable, Codable {
    /// The hinted value, or `nil` after saving, restoring or building the route from a link.
    public let wrappedValue: Value?

    /// A hint with this value, or with none.
    public init(wrappedValue: Value?)
}
```

### Route keys

Waypoint saves each route with a key, and reads the key back to find the route's type. The key is the route's module and type name, such as `Shop.ProductRoute`, so you never write one:

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    let id: Int
}

// Saved as Shop.ProductRoute, logged as ProductRoute(id: <private>).
```

Two routes can't share a key, because Swift doesn't allow two types with the same full name. Routes with the same name in two feature modules get two keys, such as `Shop.DetailRoute` and `Account.DetailRoute`.

When you rename a route type, or move it to another module, list its old key so navigation state saved by older versions still restores:

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    static let formerRouteKeys = [RouteKey("Shop.ProductDetailRoute")]

    let id: Int
}
```

You don't need to work out the old key. If you forget, the first restore after the rename logs `unknownRouteKey key=Shop.ProductDetailRoute` with the exact line to add.

Waypoint checks every key when the app starts, while the root router registers its destinations:

- A former key that belongs to another route reports `duplicateRouteKey` with both type names. The current key wins.
- A `private`, `fileprivate` or local route type reports `unstableRouteKey`, because its name changes between builds. It works on screen but is not saved. Make it `internal` or wider.
- An empty or malformed former key reports `invalidRouteKey`.

Each one fails loudly in development, never crashes in release, and fails the test in `WaypointTesting` strict mode.

```swift
/// The stable name of a route type, used when a route is saved, decoded or logged.
///
/// Conformances:
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
/// - `NavigationDescribable`, so logs and test failures print it in the shared format.
public struct RouteKey: NavigationValue, NavigationDescribable {
    /// The full key, such as `Shop.ProductRoute`.
    public var rawValue: String { get }

    /// The key without its module, such as `ProductRoute`. Logs print this.
    public var typeName: String { get }

    /// The key of a route type: its module and type name, such as `Shop.ProductRoute`.
    public init<R: Route>(_ type: R.Type)

    /// A key written out, for `formerRouteKeys` only.
    public init(_ rawValue: String)
}
```

`RouteKey` can't be written as a bare string literal, so a key is never mixed up with another string, and the one place you write one, `formerRouteKeys`, stands out in review.

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
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events
///   and test failures.
public struct AnyRoute: NavigationValue, NavigationDescribable {
    /// The wrapped route's key.
    public var routeKey: RouteKey { get }

    /// Wraps a route.
    public init<R: Route>(_ route: R)

    /// The wrapped route as `R`, or `nil` if it is another type.
    public func `as`<R: Route>(_ type: R.Type) -> R?

    /// Whether the wrapped route is of type `R`.
    public func `is`<R: Route>(_ type: R.Type) -> Bool

    // `description` is the route's type name and its fields, private by default,
    // such as `ProductRoute(id: <private>)`. See <doc:Descriptions>.
}
```

### Decoding routes

Decoding an `AnyRoute` needs to know which concrete type a key stands for. Registering a destination for a route type also registers it for decoding, so most apps never touch the registry.

The registry is also what lets a route be shown. It is strict in every build: pushing or presenting a route type with no registered destination fails with `unregisteredRoute`, runs its fallback and is logged, even before anything is registered. The mode is chosen once, in the root's `NavigationConfiguration`, and registering never changes it. Tests and previews that push routes with no destinations ask for a permissive registry by name:

```swift
let router = StackRouter(configuration: NavigationConfiguration(registry: .permissive))
```

An erased route is saved as its key and its value, such as `{"route": "Shop.ProductRoute", "value": {"id": 42}}`. Encoding needs nothing else. Decoding reads the registry from the decoder's `userInfo`:

```swift
let decoder = JSONDecoder()
decoder.userInfo[.routeRegistry] = registry
let state = try decoder.decode(StackState.self, from: data)
```

```swift
/// Maps route keys to route types, so erased routes can be encoded and decoded.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct RouteRegistry: Sendable {
    /// Problems found while registering, in the order they were found.
    public let problems: [RouteDecodingError]

    /// Every registered route type, once each.
    public var registeredTypes: [any Route.Type] { get }

    /// Creates an empty registry.
    /// Whether a route type must be registered before it can be shown.
    public enum Mode: Sendable {
        /// Only registered route types can be pushed or presented. The default.
        case strict
        /// Any route can be pushed or presented, for tests and previews.
        case permissive
    }

    /// An empty strict registry. The default.
    public static var strict: RouteRegistry { get }
    /// An empty registry that lets any route be shown, for tests and previews.
    public static var permissive: RouteRegistry { get }

    /// Chosen when the registry is made; registering never changes it.
    public let mode: Mode

    /// Creates an empty registry.
    public init(mode: Mode = .strict)

    /// The same registry with a route type added under its `routeKey` and
    /// its `formerRouteKeys`.
    ///
    /// Registering the same type twice returns the registry unchanged. A
    /// former key that belongs to another type records `duplicateRouteKey`,
    /// and a private or local type records `unstableRouteKey`.
    public func registering<R: Route>(_ type: R.Type) -> RouteRegistry

    /// Whether this route type is registered under its current key.
    public func isRegistered<R: Route>(_ type: R.Type) -> Bool

    /// Whether a route may be shown: any route when permissive, only a
    /// registered type when strict.
    public func allows(_ route: AnyRoute) -> Bool

    /// The route type for a current or former key.
    public func type(for key: RouteKey) -> (any Route.Type)?

    /// Encodes a route with its key.
    public func encode(_ route: AnyRoute, to encoder: any Encoder) throws

    /// Decodes a route by its key, or throws `RouteDecodingError`.
    public func decode(from decoder: any Decoder) throws -> AnyRoute
}

extension CodingUserInfoKey {
    /// Where a decoder finds the registry it needs to decode `AnyRoute` values.
    public static let routeRegistry: CodingUserInfoKey
}

/// Why an erased route could not be decoded.
///
/// Conformances:
/// - `Error`, so it can be thrown.
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public enum RouteDecodingError: Error, NavigationRecord {
    case unknownRouteKey(RouteKey)
    case invalidPayload(RouteKey)
    case duplicateRouteKey(RouteKey, types: [String])
    case unstableRouteKey(RouteKey)
    case invalidRouteKey(String)
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
    /// The route types registered for decoding.
    public let registry: RouteRegistry

    /// Every registered route type.
    public var registeredTypes: [any Route.Type] { get }

    /// Creates an empty table.
    public init()

    /// The same table with a way to build the payload for one route type.
    ///
    /// Also registers the type for decoding.
    public func registering<R: Route>(
        _ type: R.Type,
        _ make: @escaping (R) -> Payload
    ) -> RouteTable

    /// The payload for a route, or `nil` if its type is not registered.
    public func payload(for route: AnyRoute) -> Payload?
    /// Whether a destination is registered for this route type.
    public func contains<R: Route>(_ type: R.Type) -> Bool
}
```

A route with no destination never crashes the app. The router reports an `unregisteredRoute` issue with the file and line of the call. Debug builds show a "No destination for …" screen, and release builds refuse the push.
