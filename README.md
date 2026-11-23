![Waypoint. Connect every screen. Know every route. Typed, testable navigation for SwiftUI and UIKit.](.github/assets/banner-night.png)

<p align="center">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-FF5BAA?style=flat-square&labelColor=0B0F2A">
  <img alt="iOS 17+" src="https://img.shields.io/badge/iOS-17%2B-7C8CFF?style=flat-square&labelColor=0B0F2A">
  <img alt="SwiftUI and UIKit" src="https://img.shields.io/badge/SwiftUI%20%2B%20UIKit-renderers-7C8CFF?style=flat-square&labelColor=0B0F2A">
  <img alt="Status: in development" src="https://img.shields.io/badge/status-in%20development-FF5BAA?style=flat-square&labelColor=0B0F2A">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-EEF0FF?style=flat-square&labelColor=0B0F2A"></a>
</p>

> [!WARNING]
> **Waypoint is in development and not ready for use.** There is no release yet, and the API can still change.

Waypoint is a navigation library for iOS apps. Every screen is named by a small route value, navigation lives in routers you can read and test, and SwiftUI or UIKit only draws what the routers say.

## Status

| Part | State |
|---|---|
| Routes, route keys and descriptions | ✅ Built in `WaypointCore` |
| Navigation state and pure reducers | ✅ Built |
| `StackRouter` and `TabRouter`: push, pop, present, dismiss, tabs, the router tree | ✅ Built |
| Transactions, path helpers, `else:` fallbacks and outcomes | ✅ Built |
| Logging seam, unified log and signposts, on by default in the renderers | ✅ Built |
| One `NavigationConfiguration` on the root, strict route registry, route hints, one push per tap, the replace-presentation fallback | ✅ Built |
| SwiftUI stacks: `WaypointStack`, `destination(_:_:)`, swipe-back sync | ✅ Built in `Waypoint` |
| `WaypointLink`, navigators and property wrappers for views and view models | ✅ Built in `Waypoint` |
| SwiftUI sheets, tabs and the app coordinator | 🛰️ Next |
| Stack and tab coordinators: `StackCoordinator` and `TabCoordinator` (and `StackCoordinating` and `TabCoordinating` in `WaypointCore`) with the router made, named and released for you, and each tab's stack its coordinator's router | ✅ Built in #59 (first parts) |
| The other coordinator kinds, a coordinator's screens and `view`, swappable renderers, child flows, root switching, deep links | 📐 Designed in DocC |
| Events, guards, restoration, `WaypointTesting` | 📐 Designed in DocC |

Built parts have unit tests that run on a Mac and on Linux. Designed parts are written as signatures in the DocC articles below and follow the same rules.

## Why Waypoint

- **One route type per screen.** Adding a screen is one route type and one registration line. There is no central `switch` over every screen, and a route's key comes from its type name, so routes declare no string keys.
- **One app coordinator.** The app's navigation lives in one place: the root (login or the main tabs), the tabs, child flows and incoming links. Screens report what happened, and the coordinator decides where to go.
- **State you can read.** Routers hold the whole navigation tree: stacks, sheets, tabs and child flows. Views and view models ask to move; they never own navigation state.
- **Safe by construction.** Mistakes are caught by the compiler where possible. Values are immutable, and every change goes through a function that checks it, so an invalid state can't be made. Anything only known at run time never crashes: every call returns an outcome, can name a fallback, and reports the issue with your file and line.
- **Logs you can search.** Routes, state, outcomes and issues print one stable line each, and route values stay private unless you list them.
- **Testable without a simulator.** `WaypointCore` is plain Swift, so navigation tests run as fast unit tests, on a Mac or on Linux.
- **One coordinator for SwiftUI and UIKit.** A coordinator's screens can be SwiftUI views or UIKit view controllers, and a renderer you can swap draws it: SwiftUI's or UIKit's, picked per kind of coordinator by default, or your own. A SwiftUI app and a UIKit app use the same coordinators.

## A first look

### Routes

Name each screen with a small route:

```swift
import SwiftUI
import Waypoint

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    let id: Int
}

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct CartRoute: Route { }
```

### The router, today

`StackRouter` is built. Every call returns an outcome, and `else:` says what to do when a call can't be done:

```swift
let router = StackRouter()

router.push(ProductRoute(id: 42))

let outcome = router.popTo(CartRoute.self, else: .popToRoot)
print(outcome)
// recovered routeNotInPath by=popToRoot
```

The cart was never pushed, so the call recovers with its fallback instead of crashing. Without a fallback it returns `.failed`, and the issue names the file and line of the call.

### A flow

Give a flow its root screen and its destinations in a coordinator. Screens can be SwiftUI views or UIKit view controllers. Functions that navigate are named `show…()`:

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
final class ShopCoordinator: StackCoordinator {
    var root: some Screen {
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

The router comes from the conformance, and `ShopCoordinator().view` is the whole flow, drawn by the default renderer. Choose another with `typealias Renderer = UIKitStackRenderer`, or for the whole app in the root's configuration.

### The app

The app coordinator owns the app's navigation. Each `case` makes one named call, and functions that build a flow are named `make…Flow()`:

```swift
// Conformances:
// - `NavigationRoot`, so `RootRouter` can compare roots to know when to switch, save and restore
//   the current root, and name it in events off the main actor.
enum AppRoot: NavigationRoot {
    case login
    case main
}

// Conformances:
// - `RootCoordinator`, so `WaypointRoot` can draw it and send it incoming links.
final class AppCoordinator: RootCoordinator {
    let router = RootRouter(AppRoot.login)
    let links: LinkInbox? = nil

    func makeFlow(for root: AppRoot) -> some RootFlow {
        switch root {
        case .login:
            makeLoginFlow()
        case .main:
            makeShopFlow()
        }
    }

    func makeLoginFlow() -> LoginCoordinator {
        LoginCoordinator(onLoggedIn: { self.showMainFlow() })
    }

    func makeShopFlow() -> ShopCoordinator {
        ShopCoordinator()
    }

    func showMainFlow() {
        router.switch(to: .main)
    }
}

@main
struct ShopApp: App {
    var body: some Scene {
        WindowGroup {
            WaypointRoot {
                AppCoordinator()
            }
        }
    }
}
```

`makeFlow(for:)` returns the coordinator of each root's flow, and Waypoint draws it. The login screen doesn't import Waypoint. It calls `onLoggedIn`, and the rule for what happens next lives in one place you can test. A UIKit app uses the same coordinators and makes its window with `app.makeWindow(for: scene, options: options)` in its scene delegate. The example flows add tabs, a sheet that returns a result, and deep links.

### A test

Test navigation without drawing anything:

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

A route with no destination never crashes either. Debug builds show a screen that names the route and the fix, and release builds show a blank screen. A route type the tree doesn't know at all is refused.

## Products

| Product | What it is | Runs on |
|---|---|---|
| `WaypointCore` | The navigation state engine: routes, routers, outcomes, fallbacks, transactions and logging, with coordinators, guards, deep links, restoration and events to come. No UI framework. | iOS, macOS, Linux |
| `Waypoint` | Coordinators with screens, and the renderers that draw them: SwiftUI and UIKit renderers for roots, tabs, stacks and presented flows, `WaypointRoot`, `WaypointStack`, `WaypointLink`, logging to the unified log by default. Built on `WaypointCore`. | iOS 17+ |

`WaypointUIKit` is a placeholder today: it holds no renderer and only re-exports the unified log handler. The UIKit renderers are designed into `Waypoint`, and the placeholder will be removed.

## Requirements

- iOS 17 or later
- Swift 6.2 or later (strict concurrency)
- Xcode 26 or later, for the package and for the example app

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

`Waypoint` serves SwiftUI and UIKit apps alike, and brings `WaypointCore` with it, so a file writes only `import Waypoint`. Use `WaypointCore` alone in a module or file that only decides where to go and draws nothing; never import both.

## Documentation

The API is written in DocC articles, one per topic. Articles for built parts match the code; the rest are the design the code will follow.

**Core** (`WaypointCore`)

| Article | What it covers |
|---|---|
| [Routes](Sources/WaypointCore/WaypointCore.docc/Routes.md) | Naming screens with small route types, and route keys from the type name |
| [Navigation state](Sources/WaypointCore/WaypointCore.docc/NavigationState.md) | The navigation tree the router holds |
| [Stack navigation](Sources/WaypointCore/WaypointCore.docc/StackNavigation.md) | Push, pop and replace, outcomes and `else:` fallbacks |
| [Presentation](Sources/WaypointCore/WaypointCore.docc/PresentingFlows.md) | Sheets, full-screen covers, and sheet sizes, including sheets that fit their content |
| [Tabs](Sources/WaypointCore/WaypointCore.docc/Tabs.md) | Tab routers and their stacks |
| [Coordinators and child flows](Sources/WaypointCore/WaypointCore.docc/CoordinatorsAndChildFlows.md) | Grouping screens into flows |
| [Root switching](Sources/WaypointCore/WaypointCore.docc/RootSwitching.md) | The app coordinator, and swapping login for the main tabs |
| [Deep links](Sources/WaypointCore/WaypointCore.docc/DeepLinks.md) | URLs, push taps and shortcuts, applied in one step |
| [Guards](Sources/WaypointCore/WaypointCore.docc/Guards.md) | Allow, deny or redirect a move before it happens |
| [State restoration](Sources/WaypointCore/WaypointCore.docc/StateRestoration.md) | Saving and restoring navigation |
| [Descriptions](Sources/WaypointCore/WaypointCore.docc/Descriptions.md) | One stable, searchable line per value, with user data kept private |
| [Events and logging](Sources/WaypointCore/WaypointCore.docc/EventsAndLogging.md) | What changed, where it came from, and why |
| [Testing your navigation](Sources/WaypointCore/WaypointCore.docc/TestingYourNavigation.md) | Testing coordinators and view models without a UI |
| [Concurrency](Sources/WaypointCore/WaypointCore.docc/Concurrency.md) | The main actor, queued calls and navigators whose flow is gone |
| [Why these conformances](Sources/WaypointCore/WaypointCore.docc/WhyTheseConformances.md) | What each protocol on a route is for |

**Drawing** (`Waypoint`)

| Article | What it covers |
|---|---|
| [Coordinators and renderers](Sources/Waypoint/Waypoint.docc/Renderers.md) | One coordinator for each kind, its `view` and `viewController`, the window, and choosing or writing a renderer |
| [Navigating from views and view models](Sources/Waypoint/Waypoint.docc/NavigatingFromViewsAndViewModels.md) | Outputs, injected navigators or property wrappers |
| [The SwiftUI renderer](Sources/Waypoint/Waypoint.docc/SwiftUIRenderer.md) | Stacks, links, coordinators, sheets and tabs in SwiftUI |
| [The UIKit renderer](Sources/Waypoint/Waypoint.docc/UIKitRenderer.md) | Navigation controllers, presentations and tabs, and a UIKit app's window |
| [Example flows](Sources/Waypoint/Waypoint.docc/ExampleFlows.md) | Login, tabs, a push, a sheet and a deep link in a SwiftUI app |
| [Example flows in UIKit](Sources/Waypoint/Waypoint.docc/ExampleFlowsInUIKit.md) | The same flows and coordinators in a UIKit app |

## Contributing

Read [TESTING.md](TESTING.md) for which tests run where and how to run them, [CONTRIBUTING.md](CONTRIBUTING.md) for how pull requests are made, and [CODE_STYLE.md](CODE_STYLE.md) for the code style. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

Waypoint is available under the MIT license. See [LICENSE](LICENSE).
