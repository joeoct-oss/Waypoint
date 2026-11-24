# Concurrency

Which types live on the main actor, which values can go anywhere, and what happens to calls made at awkward moments.

## Overview

Waypoint is written in the Swift 6 language mode with strict concurrency checking. The rules are short:

| Kind | Isolation | Built today |
|---|---|---|
| Objects that own or change navigation | `@MainActor` | `StackRouter`, `TabRouter`, `StackNavigator`, `FlowNavigator`, `NavigationTransaction` |
| Values that describe navigation | `Sendable` | Routes, `AnyRoute`, `StackState`, `TabState`, `Presentation`, `NavigationTree`, `NavigationChange`, `NavigationOutcome`, `NavigationIssue`, `ScreenVisit`, `NavigationConfiguration`, `FallbackPolicy`, `LogConfiguration`, `RouteRegistry` |

Values can leave the main actor freely, for logging, analytics or saving. Changing navigation always happens on the main actor, which is also where the renderers draw.

Planned types follow the same rules when they land: coordinators ([#59](https://github.com/joeoct-oss/Waypoint/issues/59)), events and observers ([#23](https://github.com/joeoct-oss/Waypoint/issues/23)), guards ([#40](https://github.com/joeoct-oss/Waypoint/issues/40)), the link inbox and navigation plans ([#15](https://github.com/joeoct-oss/Waypoint/issues/15)), and snapshots ([#16](https://github.com/joeoct-oss/Waypoint/issues/16)).

Each promise below names the tests that keep it, in [`Tests/WaypointCoreTests/Concurrency`](https://github.com/joeoct-oss/Waypoint/tree/main/Tests/WaypointCoreTests/Concurrency). Those tests use the public API only, the way an app does.

### The compiler keeps you on the main actor

Calling a router or a navigator, or reading a router's state, from code that isn't on the main actor doesn't compile. A route, a log handler or any other value Waypoint sends between threads must be `Sendable`, so a route that stores a mutable class doesn't compile either. The compile fixtures in [`Tests/CompileFailures`](https://github.com/joeoct-oss/Waypoint/tree/main/Tests/CompileFailures) check each case.

An app still in the Swift 5 language mode gets the same errors for calls off the main actor. The `Sendable` checks are only warnings there, so turn on complete checking or move to Swift 6.

Your own callbacks, such as `onNavigationFailure` and custom fallbacks, run on the main actor, so they can touch the UI directly.

### Calling from other contexts

From a background task or another actor, await the call. It hops to the main actor:

```swift
Task.detached {
    let order = try await api.placeOrder()
    await router.push(OrderConfirmationRoute(id: order.id))
}
```

View models that hold a navigator are `@MainActor`, like the views that own them, so they call it directly. Many tasks navigating at once lose nothing: each call is applied once, in the order the main actor runs them. Tests: [`BackgroundNavigationTests`](https://github.com/joeoct-oss/Waypoint/blob/main/Tests/WaypointCoreTests/Concurrency/BackgroundNavigationTests.swift).

Saving and restoring a path can happen off the main actor too: encode the path anywhere, decode it with the registry in `decoder.userInfo[.routeRegistry]`, then call `setPath` on the main actor. Configurations, fallback policies and descriptions can be built and read on any thread. Tests: [`CrossActorValueTests`](https://github.com/joeoct-oss/Waypoint/blob/main/Tests/WaypointCoreTests/Concurrency/CrossActorValueTests.swift).

> Note: Awaiting a flow's result, such as `await router.present(child)`, is planned in [#60](https://github.com/joeoct-oss/Waypoint/issues/60). It will resume on the main actor and deliver the result exactly once.

### Calls made during a change

Every change runs on the main actor, but a change can still trigger another call before it has finished: a failure handler, a custom fallback, a transaction's closure, or a screen that appears because of the change calls `push`. Waypoint never applies that call in the middle. It waits in a queue and runs right after the current change, before the outer call returns, in the order the calls were made, across every router of the tree.

```swift
let configuration = NavigationConfiguration { [weak self] failure in
    // Returns .queued and runs right after the change that failed.
    self?.router?.present(SupportRoute())
}
```

- The call returns `.queued`. If it fails when it runs, it reports an issue and runs its fallback like any other call.
- Each queued call logs `reentrantChange` at the debug level, with its file and line. It isn't an issue, and the failure handler doesn't hear about it: navigating from a callback or `onAppear` is allowed.
- A queued call whose flow closed, or whose navigator's screen was popped, by an earlier queued call is ignored when its turn comes.
- Observers never see a change half applied. A transaction that changes two routers tells every Observation observer before either router's state changes, so a view never sees one router changed and the other not yet.
- A callback that navigates on every change would loop. After `maxQueuedChanges` calls are queued during one outermost call (32 by default, set once in the root's `NavigationConfiguration`), the rest are dropped and `reentrantLoop` is reported once, at the fault level. The failure handler hears it once too, so a handler that navigates can't loop on the refusal. The next outermost call starts counting again.

Tests: [`QueuedCallTests`](https://github.com/joeoct-oss/Waypoint/blob/main/Tests/WaypointCoreTests/Concurrency/QueuedCallTests.swift) and [`NavigationLoopTests`](https://github.com/joeoct-oss/Waypoint/blob/main/Tests/WaypointCoreTests/Concurrency/NavigationLoopTests.swift).

> Note: Guards ([#40](https://github.com/joeoct-oss/Waypoint/issues/40)) will be the exception. A guard decides on a change, so a navigation call inside `evaluate` will be rejected; it returns `.redirect` instead.

### Late replies: navigators belong to a screen

A navigator belongs to one screen: the screen a destination closure draws, or the screen on top of the stack when you take `router.navigator`. It holds its router weakly. When that screen is popped, or its flow is gone (dismissed, its tab removed, its router released), the navigator does nothing:

```swift
func showReviews() async {
    await reviews.load(productID: id)
    // Returns .ignored if the user already left the screen.
    navigation.push(ReviewsRoute(id: id))
}
```

- Every call returns `.ignored` and leaves the tree alone, so a late call can't move a screen that now sits where the old one was, even one showing the same route.
- A screen still on the stack keeps a live navigator, however many screens are pushed above it. A navigator taken for the root screen lives as long as its flow. The property wrappers' navigators belong to the root screen, since they are read again on every draw.
- Each ignored call logs `staleNavigator` at the debug level, with its file and line. It isn't an issue, and the failure handler doesn't hear about it, because replies that arrive after a screen closes are normal.
- `navigation.isActive` tells you whether the screen and its flow are still there; `router.isActive` whether the router is still in the tree.
- A view model that keeps a navigator doesn't keep a closed flow alive.
- A `NavigationTransaction` works only inside its closure. Kept and used after the call returned, every step returns `.ignored` and changes nothing.

Tests: [`StaleNavigatorTests`](https://github.com/joeoct-oss/Waypoint/blob/main/Tests/WaypointCoreTests/Concurrency/StaleNavigatorTests.swift).

> Note: Treating an ignored call as a test failure with `StrictMode(failOn:)` is planned in [#41](https://github.com/joeoct-oss/Waypoint/issues/41).

### Inside the package

- No unsafe concurrency escape (`@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency`, `assumeIsolated`, unsafe pointers) without a written reason and an entry in the guard rail's allowlist. Today there is one: the unified log handler's channels, guarded by a lock.
- No locks, queues or detached tasks in the core. The main actor is the only writer.
- The package builds with no warnings, tests included, with warnings as errors on Linux, macOS and iOS, and the tests pass under the thread sanitizer.

`scripts/check-concurrency.sh` enforces the first two and checks that the concurrency tests use the public API only. `scripts/test-linux.sh` and `scripts/test-mac.sh` run it with the rest.
