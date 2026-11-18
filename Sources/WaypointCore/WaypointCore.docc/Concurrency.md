# Concurrency

Which types live on the main actor, and which values can go anywhere.

## Overview

> Note: Draft until #24. The API in this article is planned, not built, and can still change when #24 lands.

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

### Calls made during a change

Every change runs on the main actor, but a change can still trigger another call before it has finished: an observer, an event handler, or a screen that appears because of the change calls `push`. Waypoint never applies that call in the middle. It waits in a queue and runs right after the current change and its observers, in the same turn and in the order the calls were made.

```swift
router.onEvents { [weak self] events in
    self?.showOnboardingIfNeeded()
}

func showOnboardingIfNeeded() {
    guard needsOnboarding else {
        return
    }

    router.present(OnboardingRoute())   // returns .queued and runs right after this change
}
```

- The call returns `.queued`. If it fails when it runs, it reports an issue and runs its fallback like any other call.
- Each queued call logs `reentrantChange` at the debug level, with its file and line. It isn't an issue: navigating from an observer or `onAppear` is allowed.
- An observer that navigates on every change would loop. After `maxQueuedChanges` queued calls in one turn (32 by default, set once in the root's `NavigationConfiguration`), the rest are dropped and `reentrantLoop` is reported.
- Guards are the exception. A guard decides on a change, so a navigation call inside `evaluate` is rejected. Return `.redirect` instead.

### Navigators that outlive their flow

A navigator holds its router weakly, with the flow it was made for. When that flow is gone (popped, dismissed, finished, replaced by a root switch), the navigator does nothing:

```swift
func showReviews() async {
    await reviews.load(productID: id)
    navigation.push(ReviewsRoute(id: id))   // returns .ignored if the user already closed the screen
}
```

- Every call returns `.ignored` and leaves the tree alone, so a late call can't move a screen that now sits where the old one was.
- Each one logs `staleNavigator` at the debug level, with its file and line. It isn't an issue, because replies that arrive after a screen closes are normal. To treat it as a bug in tests, pass `.ignored` along with `.failed` to `StrictMode(failOn:)`.
- `navigation.isActive` tells you whether the flow is still there.
- A view model that keeps a navigator doesn't keep a closed flow alive.

### Inside the package

- No `@unchecked Sendable` without a written reason next to it.
- No locks around navigation state. The main actor is the only writer.
- The core builds with no concurrency warnings on every supported platform, including Linux.
