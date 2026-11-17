![Waypoint. Connect every screen. Know every route. Typed, testable navigation for SwiftUI and UIKit.](.github/assets/banner-night.png)

<p align="center">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-FF5BAA?style=flat-square&labelColor=0B0F2A">
  <img alt="iOS 17+" src="https://img.shields.io/badge/iOS-17%2B-7C8CFF?style=flat-square&labelColor=0B0F2A">
  <img alt="SwiftUI and UIKit" src="https://img.shields.io/badge/SwiftUI%20%2B%20UIKit-renderers-7C8CFF?style=flat-square&labelColor=0B0F2A">
  <img alt="Status: in development" src="https://img.shields.io/badge/status-in%20development-FF5BAA?style=flat-square&labelColor=0B0F2A">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-EEF0FF?style=flat-square&labelColor=0B0F2A"></a>
</p>

> [!WARNING]
> **Waypoint is in development and not ready for use.** The API is designed and documented in the DocC articles below, but it is not implemented yet. There is no release, and the API can still change.

Waypoint is a navigation library for iOS apps. Every screen is named by a small route value, navigation lives in a router you can read and test, and SwiftUI or UIKit only draws what the router says.

## Why Waypoint

- **One route type per screen.** Adding a screen is one route type and one registration line. There is no central `switch` to grow.
- **State you can read.** The router holds the whole navigation tree: stacks, sheets, tabs and child flows. Views and view models ask it to move; they never own navigation state.
- **Safe by construction.** Mistakes are caught by the compiler where possible. Anything only known at run time never crashes: it falls back, and debug builds tell you exactly what went wrong and where.
- **Testable without a simulator.** `WaypointCore` is plain Swift, so navigation tests run as fast unit tests, on a Mac or on Linux.
- **SwiftUI and UIKit.** Both renderers draw the same core state, so a flow can mix SwiftUI and UIKit screens.
- **Deep links and restoration.** Routes are `Codable`, so a link or a saved session is just a list of routes.

## A first look

Name a screen with a route:

```swift
import SwiftUI
import Waypoint
import WaypointCore

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    let id: Int
}
```

Give a flow its root screen and its destinations in a coordinator:

```swift
// Conformances:
// - `SwiftUIStackCoordinator`, so `WaypointStack` can draw it.
final class ShopCoordinator: SwiftUIStackCoordinator {
    let router = StackRouter()

    var root: some View {
        ProductListView(onSelect: { self.showProduct(id: $0) })
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { route in
            ProductView(id: route.id)
        }
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }
}
```

Draw it:

```swift
WaypointStack(ShopCoordinator())
```

A whole app keeps its navigation in an app coordinator: the root (login or the main tabs), the tabs, its child coordinators and incoming links. The `App` only hands it to Waypoint:

```swift
@main
struct ShopApp: App {
    @State private var app = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            WaypointRoot(app)
        }
    }
}
```

Screens report what happened, such as "logged in", and the app coordinator decides where to go. The SwiftUI example flows show the whole `AppCoordinator`.

And test it without drawing anything:

```swift
@Test @MainActor
func selectingAProductPushesIt() {
    let shop = ShopCoordinator()

    shop.showProduct(id: 42)

    expectPath(shop.router) {
        ProductRoute(id: 42)
    }
}
```

A route with no destination never crashes. Debug builds show a screen that names the route and the fix, and release builds refuse the push.

## Products

| Product | What it is | Runs on |
|---|---|---|
| `WaypointCore` | The navigation state engine: routes, routers, coordinators, guards, deep links, restoration and events. No UI framework. | iOS, macOS, Linux |
| `Waypoint` | The SwiftUI renderer: `WaypointStack`, sheets, tabs, `WaypointLink` and coordinators. Built on `WaypointCore`. | iOS 17+ |
| `WaypointUIKit` | The UIKit renderer: navigation controllers, presentations and tab bar controllers driven by the same core. | iOS 17+ |

## Requirements

- iOS 17 or later
- Swift 6 (strict concurrency)
- Xcode 16 or later

## Installation

Waypoint is not released yet. When it is, add it with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/JoeOCT91/Waypoint.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "Waypoint", package: "Waypoint"),
        ]
    ),
]
```

Use `WaypointUIKit` for UIKit screens, and `WaypointCore` alone in a module that only decides where to go.

## Documentation

The API is designed in DocC articles, one per topic.

**Core** (`WaypointCore`)

| Article | What it covers |
|---|---|
| [Routes](Sources/WaypointCore/WaypointCore.docc/Routes.md) | Naming screens with small route types |
| [Navigation state](Sources/WaypointCore/WaypointCore.docc/NavigationState.md) | The navigation tree the router holds |
| [Stack navigation](Sources/WaypointCore/WaypointCore.docc/StackNavigation.md) | Push, pop and replace, and what every call did |
| [Presentation](Sources/WaypointCore/WaypointCore.docc/Presentation.md) | Sheets, full-screen covers and sheet sizes |
| [Tabs](Sources/WaypointCore/WaypointCore.docc/Tabs.md) | Tab routers and their stacks |
| [Coordinators and child flows](Sources/WaypointCore/WaypointCore.docc/CoordinatorsAndChildFlows.md) | Grouping screens into flows |
| [Root switching](Sources/WaypointCore/WaypointCore.docc/RootSwitching.md) | Swapping whole flows, such as login and the main tabs |
| [Deep links](Sources/WaypointCore/WaypointCore.docc/DeepLinks.md) | URLs, push taps and shortcuts, applied in one step |
| [Guards](Sources/WaypointCore/WaypointCore.docc/Guards.md) | Allow, deny or redirect a move before it happens |
| [State restoration](Sources/WaypointCore/WaypointCore.docc/StateRestoration.md) | Saving and restoring navigation |
| [Events and logging](Sources/WaypointCore/WaypointCore.docc/EventsAndLogging.md) | What changed, where it came from, and why |
| [Testing your navigation](Sources/WaypointCore/WaypointCore.docc/TestingYourNavigation.md) | Testing coordinators and view models without a UI |
| [Concurrency](Sources/WaypointCore/WaypointCore.docc/Concurrency.md) | Which types live on the main actor |
| [Why these conformances](Sources/WaypointCore/WaypointCore.docc/WhyTheseConformances.md) | What each protocol on a route is for |

**SwiftUI** (`Waypoint`)

| Article | What it covers |
|---|---|
| [The SwiftUI renderer](Sources/Waypoint/Waypoint.docc/SwiftUIRenderer.md) | Stacks, links, coordinators, sheets and tabs |
| [Navigating from views and view models](Sources/Waypoint/Waypoint.docc/NavigatingFromViewsAndViewModels.md) | Outputs, injected navigators or property wrappers |
| [Example flows](Sources/Waypoint/Waypoint.docc/ExampleFlows.md) | Login, tabs, a push, a sheet and a deep link |

**UIKit** (`WaypointUIKit`)

| Article | What it covers |
|---|---|
| [The UIKit renderer](Sources/WaypointUIKit/WaypointUIKit.docc/UIKitRenderer.md) | Navigation controllers, presentations and tabs |
| [Example flows in UIKit](Sources/WaypointUIKit/WaypointUIKit.docc/ExampleFlowsInUIKit.md) | The same flows with view controllers |

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for how to run the tests and how pull requests are made. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

Waypoint is available under the MIT license. See [LICENSE](LICENSE).
