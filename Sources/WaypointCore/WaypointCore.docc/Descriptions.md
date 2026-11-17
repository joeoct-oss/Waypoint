# Descriptions

Print every navigation value as one stable, searchable line that keeps user data private.

## Overview

Logs, events, issues, `debugTree()`, journey tracking and test failures all print Waypoint values. Each value prints in the same shape, so log tools can parse it with one rule, and route fields never leave the device unless the route says they may.

```swift
print(event)
// pushed [ProductRoute(id: <private>)] flow=shop origin=user tx=12

print(outcome)
// recovered routeNotInPath by=popToRoot
```

### The protocol

```swift
/// A value with a short, stable, private-by-default description.
///
/// Conformances:
/// - `CustomStringConvertible`: `description` is the one-line form for logs and events.
/// - `CustomDebugStringConvertible`: `debugDescription` is the detailed form for debugging.
public protocol NavigationDescribable: CustomStringConvertible, CustomDebugStringConvertible {
    /// The detailed form, with route field values shown or redacted.
    func debugDescription(revealingPrivateValues: Bool) -> String
}

extension NavigationDescribable {
    /// Same as `debugDescription(revealingPrivateValues: false)`.
    public var debugDescription: String { get }
}
```

These types conform:

- **Routes and state:** `AnyRoute`, `FlowID`, `StackState`, `TabState`, `Presentation`, `PresentationStyle` and `NavigationTree`.
- **Changes and events:** `NavigationChange`, `NavigationEvent`, `NavigationOrigin` and `TransactionID`.
- **Results and errors:** `NavigationOutcome`, `NavigationIssue`, `NavigationFailure`, `NavigationFallback`, `RouteDecodingError` and `RestoreOutcome`.
- **Saving and links:** `NavigationSnapshot` and `NavigationPlan`.

Routers and coordinators don't conform. Their state lives on the main actor, while a description can be read from any thread. Every description names them by their `FlowID`, and `debugTree()` prints them.

### The format

- `description` is one line. It starts with a fixed word: a case name, a route's type name or a flow name. Then come `key=value` pairs. Lists are `[a, b]`, and a change from one value to another is `a -> b`.
- `debugDescription` starts with the `description` and adds detail, such as an issue's message or the whole tree.
- Routes print by their key's `typeName`, the key without its module, such as `ProductRoute`. Saved snapshots and decoding errors use the full key, such as `Shop.ProductRoute`.

| Value | `description` |
|---|---|
| A route | `ProductRoute(id: <private>)`, `CartRoute`, `CheckoutStep.payment`, `PaymentRoute.card(id: <private>)` |
| A route with `publicLogFields = ["id"]` | `ProductRoute(id: 42)` |
| `StackState` | `[ProductListRoute(category: <private>), ProductRoute(id: <private>)]` |
| `TabState` | `[home, *shop, profile]`, where `*` marks the selected tab |
| `PresentationStyle` | `sheet`, `sheet(detents: [medium, large])`, `fullScreenCover` |
| `Presentation` | `sheet FilterRoute flow=filter` |
| `NavigationChange` | `pushed [ProductRoute(id: <private>)]`, `popped [CartRoute]`, `tabSelected home -> shop`, `dismissed flow=filter` |
| `NavigationEvent` | `pushed [ProductRoute(id: <private>)] flow=shop origin=user tx=12` |
| `NavigationOutcome` | `applied`, `alreadyThere`, `queued`, `ignored`, `recovered routeNotInPath by=popToRoot`, `failed routeNotInPath` |
| `NavigationIssue` | `routeNotInPath flow=shop at=ShopCoordinator.swift:42` |
| `NavigationFailure` | `failed routeNotInPath flow=shop at=ShopCoordinator.swift:42 fallback=popToRoot fallbackIssue=emptyPath` |
| `NavigationFallback` | `popToRoot`, `custom(showHome)` |
| `NavigationTree` | `root(main) > tabs[home, *shop, profile] > stack[ProductListRoute(category: <private>)] + sheet[FilterRoute]` |
| `RouteDecodingError` | `unknownRouteKey key=Shop.OldProductRoute` |
| `RestoreOutcome` | `restored`, `partial issues=2`, `failed reason="unknown version 3"` |
| `NavigationSnapshot` | `snapshot version=1 flows=4` |

An issue's detailed form adds its message:

```text
routeNotInPath flow=shop at=ShopCoordinator.swift:42
  HomeRoute is not in the path [ProductListRoute(category: <private>), ProductRoute(id: <private>)].
  Pass a fallback, such as popTo(HomeRoute.self, else: .popToRoot), or call setFallback(.popToRoot, for: .routeNotInPath).
```

A tree's detailed form is the indented `debugTree()` output.

### Private by default

- Route field values print as `<private>`, unless the route lists the field in `publicLogFields`.
- Names always print, because they describe structure, not user data: route keys, case names, flow names, tab and root names, counts, and file and line. Associated values in tab and root types are private, like route fields.
- `description` and `debugDescription` never reveal. Only `debugDescription(revealingPrivateValues: true)` does. Waypoint calls it in two places: the logger, when `LogConfiguration.revealsPrivateValues` is on, and the `WaypointTesting` failure messages.
- Waypoint builds a route's description itself and ignores a `description` your route declares, so a custom description can't leak a field.

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    static let publicLogFields: Set<String> = ["id"]   // a product id is not user data
    let id: Int
    let searchQuery: String?                            // stays private
}
// ProductRoute(id: 42, searchQuery: <private>)
```

### A stable format

The `description` format is part of the API. A change to it is listed in the changelog like any other change to a public signature, so dashboards and alerts built on it keep working.

Logging builds a description only when its level and category are enabled, so a disabled log line costs nothing.
