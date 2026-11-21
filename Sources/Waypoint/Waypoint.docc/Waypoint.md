# ``Waypoint``

Draw Waypoint navigation with SwiftUI or UIKit, and mix them in one app.

@Metadata {
    @PageImage(purpose: card, source: "waypoint-card", alt: "Three SwiftUI screens pushed one after another along a route.")
}

## Overview

Waypoint draws the routers of `WaypointCore`. You write one coordinator for each flow, with SwiftUI views or UIKit view controllers as its screens, and a renderer draws it: SwiftUI's `NavigationStack`, sheets and tab views, or UIKit's navigation, sheet and tab bar controllers. Waypoint picks the best renderer for each kind of coordinator by default, and you can choose another or bring your own. What the user changes by hand (swipe back, sheet drags, tab taps) goes back to the routers in every renderer.

The simplest app needs one line per screen and no coordinator:

```swift
WaypointStack { HomeView() }
    .destination(ProductRoute.self) { ProductView(id: $0.id) }
    .destination(CartRoute.self) { _ in CartView() }
```

A whole app starts from an app coordinator: `WaypointRoot` draws it in a SwiftUI app, one for each window, and `makeWindow(for:options:)` in a UIKit scene delegate. See <doc:ExampleFlows> and <doc:ExampleFlowsInUIKit>.

Routes, routers, outcomes and everything that isn't drawing are documented in the `WaypointCore` catalog.

## Topics

### Essentials

- <doc:Renderers>
- <doc:NavigatingFromViewsAndViewModels>

### Renderers

- <doc:SwiftUIRenderer>
- <doc:UIKitRenderer>

### Examples

- <doc:ExampleFlows>
- <doc:ExampleFlowsInUIKit>
