# Why these conformances

What each protocol on a route, tab or root type is for, and what breaks without it.

## Overview

Every type in these articles lists its conformances and gives a reason for each one. Most of your own types need the same three, and this page explains them once.

### Conformances that travel together

Many types need the same set for the same reasons, so Waypoint names each set once. A type then lists one name, and its reasons are written in one place:

| Name | Kind | Is | For |
|---|---|---|---|
| `NavigationValue` | Type alias | `Hashable & Codable & Sendable` | Values the navigation keeps and looks up: `FlowID`, `RouteKey`, `AnyRoute`, `PresentationStyle`, `SheetOptions`, `SheetDetent` |
| `NavigationRecord` | Type alias | `Sendable & Equatable & NavigationDescribable` | Values the navigation reports: changes, outcomes, issues, failures, fallbacks, events and plans |
| `NavigationStateValue` | Type alias | `NavigationRecord & Codable` | The parts of the navigation state: `StackState`, `TabState`, `Presentation`, `NavigationTree` |
| `Route` | Protocol | `NavigationValue` and a route key | Your route types |
| `NavigationTab` | Protocol | `NavigationValue` | Your tab types |
| `NavigationRoot` | Protocol | `NavigationValue` | Your root types |

A type alias works like `Codable`: it is only a name for the protocols together, so it costs nothing and a type that already has them conforms without saying so. Waypoint uses aliases for its own value types. Your own types use protocols: you say what a type is for in one word, `enum MainTab: NavigationTab`, the compiler names that word when something is missing, and Waypoint can add defaults to it later.

| Conformance | Needed by | Why | Without it |
|---|---|---|---|
| `Hashable` | Routes, tab types, root types | The router compares values: is this route already on top, which tab is selected, has the root changed. Paths are searched, and flows and tabs are used as dictionary keys. | `popTo`, `contains` and tab selection can't find anything, and the type doesn't compile as a route. |
| `Codable` | Routes, tab types, root types, all navigation state | The navigation tree can be saved and restored, built from a deep link, and written to logs in a stable form. | Restoration and deep links can't rebuild the screen. |
| `Sendable` | Routes, tab types, root types, all values | Routers live on the main actor, but events, snapshots and logs are handed to code that may run elsewhere: a logger, an analytics service, a background save. Swift 6 only lets values cross that boundary when they are `Sendable`. | Strict concurrency checking rejects the code. |
| `Equatable` | State, events, outcomes, issues | Tests compare them with `#expect`, and the router skips a change that leaves the state equal. | Tests need hand-written comparisons. |
| `NavigationDescribable` | Routes, state, events, outcomes, issues, snapshots | Logs, events and test failures print one stable, searchable line per value, and route fields stay private unless the route opts in. See <doc:Descriptions>. | Values print with Swift's default reflection, which changes between versions and prints every field. |
| `AnyObject` | Coordinators, routers, observers, guards | Each one is a single shared object with identity. Routers hold coordinators weakly and keep observers and guards until their token is cancelled. | A copy would be notified instead of the original. |

### Your route types

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved. `Route` already includes
//   `Hashable`, `Codable` and `Sendable`, so there's nothing else to write.
struct ProductRoute: Route {
    let id: Int
}
```

The compiler synthesizes all three for a struct or enum whose stored values already conform. Keep routes to identifiers and small inputs so that stays true.

### Your tab and root types

Tab types conform to `NavigationTab`, and root types to `NavigationRoot`. Both are `Hashable`, `Codable` and `Sendable` for the same reasons as routes. A `String` raw value is optional, and it gives each case a readable name in logs and saved state.

```swift
// Conformances:
// - `String` raw value: gives each case a readable name in logs and saved state.
// - `NavigationTab`, so `TabRouter` can select and compare tabs, save and restore the selection,
//   and name tabs in events off the main actor.
enum MainTab: String, NavigationTab {
    case home
    case shop
    case profile
}
```
