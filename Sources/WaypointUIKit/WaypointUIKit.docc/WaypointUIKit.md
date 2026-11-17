# ``WaypointUIKit``

Draw Waypoint navigation with UIKit, and mix it with SwiftUI.

## Overview

WaypointUIKit is the UIKit renderer for `WaypointCore`. It drives a `UINavigationController`, presents sheets and full-screen covers, and draws tab bar controllers from the same routers the SwiftUI renderer uses. A UIKit flow can present a SwiftUI flow and the reverse, because both renderers draw the same router tree.

```swift
let router = StackRouter()
let navigation = WaypointNavigationController(router: router, root: HomeViewController())
navigation.destination(ProductRoute.self) { ProductViewController(id: $0.id) }
```

## Topics

### Essentials

- <doc:UIKitRenderer>

### Examples

- <doc:ExampleFlowsInUIKit>
