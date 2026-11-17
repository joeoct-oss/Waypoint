# Why these conformances

What each protocol on a route, tab or root type is for, and what breaks without it.

## Overview

Every type in these articles lists its conformances and gives a reason for each one. Most of your own types need the same three, and this page explains them once.

| Conformance | Needed by | Why | Without it |
|---|---|---|---|
| `Hashable` | Routes, tab types, root types | The router compares values: is this route already on top, which tab is selected, has the root changed. Paths are searched, and flows and tabs are used as dictionary keys. | `popTo`, `contains` and tab selection can't find anything, and the type doesn't compile as a route. |
| `Codable` | Routes, tab types, root types, all navigation state | The navigation tree can be saved and restored, built from a deep link, and written to logs in a stable form. | Restoration and deep links can't rebuild the screen. |
| `Sendable` | Routes, tab types, root types, all values | Routers live on the main actor, but events, snapshots and logs are handed to code that may run elsewhere: a logger, an analytics service, a background save. Swift 6 only lets values cross that boundary when they are `Sendable`. | Strict concurrency checking rejects the code. |
| `Equatable` | State, events, outcomes, issues | Tests compare them with `#expect`, and the router skips a change that leaves the state equal. | Tests need hand-written comparisons. |
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

`TabRouter` and `RootRouter` require `Hashable & Codable & Sendable` for the same reasons. A `String` raw value is optional, and it gives each case a readable name in logs and saved state.

```swift
// Conformances:
// - `String` raw value: gives each case a readable name in logs and saved state.
// - `Hashable`, required by `TabRouter`, which selects and compares tabs.
// - `Codable`, required by `TabRouter`, which saves and restores the selection with the tree.
// - `Sendable`, required by `TabRouter`, so events that name the tab can leave the main actor.
enum MainTab: String, Hashable, Codable, Sendable {
    case home
    case shop
    case profile
}
```
