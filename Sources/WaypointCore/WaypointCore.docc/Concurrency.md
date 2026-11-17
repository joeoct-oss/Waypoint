# Concurrency

Which types live on the main actor, and which values can go anywhere.

## Overview

Waypoint is written in the Swift 6 language mode with strict concurrency checking. The rules are short:

| Kind | Isolation | Examples |
|---|---|---|
| Objects that own or change navigation | `@MainActor` | Routers, coordinators, handles, observers, guards, the link inbox |
| Values that describe navigation | `Sendable` | Routes, state, events, issues, outcomes, plans, snapshots |

Values can leave the main actor freely, for logging, analytics or saving. Changing navigation always happens on the main actor, which is also where the renderers draw.

### Calling from other contexts

From a background task, hop to the main actor first:

```swift
Task {
    let order = try await api.placeOrder()
    await MainActor.run { router.push(OrderConfirmationRoute(id: order.id)) }
}
```

View models that hold a handle are `@MainActor`, like the views that own them, so they call the handle directly.

### Async results

`await router.present(child)` and other async APIs resume on the main actor. A flow's result is delivered exactly once, even if the user dismisses the flow while code is finishing it.

### Inside the package

- No `@unchecked Sendable` without a written reason next to it.
- No locks around navigation state. The main actor is the only writer.
- The core builds with no concurrency warnings on every supported platform, including Linux.
