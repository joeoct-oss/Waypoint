# ``Waypoint``

Draw Waypoint navigation with SwiftUI.

@Metadata {
    @PageImage(purpose: card, source: "waypoint-card", alt: "Three SwiftUI screens pushed one after another along a route.")
}

## Overview

Waypoint is the SwiftUI renderer for `WaypointCore`. It turns routers into `NavigationStack`s, sheets, full-screen covers and tab views, and reports what the user changes by hand (swipe back, sheet drags, tab taps) back to the routers.

The simplest app needs one line per screen and no coordinator:

```swift
WaypointStack { HomeView() }
    .destination(ProductRoute.self) { ProductView(id: $0.id) }
    .destination(CartRoute.self) { _ in CartView() }
```

A whole app starts from an app coordinator drawn by `WaypointRoot`, one for each window. See <doc:ExampleFlows>.

Routes, routers, outcomes and everything that isn't SwiftUI are documented in the `WaypointCore` catalog.

## Topics

### Essentials

- <doc:SwiftUIRenderer>
- <doc:NavigatingFromViewsAndViewModels>

### Examples

- <doc:ExampleFlows>
