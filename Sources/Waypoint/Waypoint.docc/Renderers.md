# Coordinators and renderers

Write one coordinator for each flow, in SwiftUI views or UIKit view controllers, and choose what draws it.

## Overview

> Note: Draft until #59. The coordinator protocols with screens are built in #59, the SwiftUI renderer for every kind in #12, #13 and #37, and the UIKit stack renderer in #14. UIKit tabs and presented flows follow in #50 and #49. Names and signatures in this article can still change until then. Today a stack is drawn by `WaypointStack`, which is built: see <doc:SwiftUIRenderer>.

An app writes one coordinator for each flow, whichever kind of app it is. The coordinator says what its screens are, and a renderer draws them. Waypoint has two renderers for each kind of coordinator, one in SwiftUI and one in UIKit, and picks the best one by default. An app can choose another one for the whole app or for one coordinator, or bring its own.

### One coordinator for each kind

| Coordinator | Owns | Has its own renderer |
|---|---|---|
| `RootCoordinator`, the app coordinator | The window's `RootRouter`, which switches between roots such as login and the main tabs | Yes |
| `TabCoordinator` | A `TabRouter`, and one stack coordinator for each tab | Yes |
| `StackCoordinator` | A `StackRouter`: a tab's stack, or a root's stack | Yes |
| `FlowCoordinator`, presented | A `StackRouter` shown as a sheet or a full-screen cover, which ends with a result | Yes |
| `FlowCoordinator`, pushed | Its own routes, inside its parent's stack | No: its parent's renderer draws it |

A coordinator's `root` and `destinations` take either kind of screen, written the natural way. App code never wraps a screen by hand:

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
        Destination(ScannerRoute.self) { _ in
            ScannerViewController()
        }
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }
}
```

`ProductView` is a SwiftUI view and `ScannerViewController` is a `UIViewController`. Both work in either renderer: the SwiftUI renderer shows a controller through a representable, and the UIKit renderer shows a SwiftUI view in a `UIHostingController`.

A coordinator writes only what is its own: its screens, its flows and its logic. Everything else comes from the conformance and has a default you can override by declaring the member: a stack's or flow's router (made the first time it is read, and released when the flow ends; the app coordinator and a tab coordinator declare theirs, because only the app knows its first root or tab), the router's name, the registration of every destination, the navigators, `view`, `viewController` and the renderer.

```swift
/// App code that owns one stack flow, with its screens.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol StackCoordinator: AnyObject {
    /// Conformances:
    /// - `Screen`: the flow's first screen, a SwiftUI view or a view controller.
    associatedtype RootScreen: Screen
    /// Conformances:
    /// - `Destinations`: the flow's screens, by route type.
    associatedtype Body: Destinations
    /// Conformances:
    /// - `StackRenderer`: what draws this coordinator. Default: `DefaultStackRenderer`.
    associatedtype Renderer: StackRenderer = DefaultStackRenderer

    /// The router this coordinator owns. Default: made on first read.
    var router: StackRouter { get }
    /// The flow's first screen.
    @ScreenBuilder var root: RootScreen { get }
    /// The flow's screens, by route type.
    @DestinationsBuilder var destinations: Body { get }
    /// The whole flow, drawn by `Renderer`. Default: filled in by Waypoint.
    var view: Renderer { get }
}

#if canImport(UIKit)
extension StackCoordinator {
    /// `view` in a `UIHostingController`, for UIKit code that needs a controller.
    public var viewController: UIViewController { get }
}
#endif

/// A screen: any SwiftUI `View` or any `UIViewController`, through two builder overloads.
public protocol Screen { }

/// Builds a coordinator's `root` from a SwiftUI view or a view controller.
@resultBuilder
public enum ScreenBuilder {
    public static func buildBlock<V: View>(_ view: V) -> some Screen

    #if canImport(UIKit)
    public static func buildBlock<C: UIViewController>(_ controller: C) -> some Screen
    #endif

    /* `buildEither` and `buildOptional`, so `if` and `switch` work as in `@ViewBuilder` */
}

/// A group of destinations, built with `@DestinationsBuilder`.
public protocol Destinations { }

/// Builds a coordinator's `destinations` from `Destination` and `Flow` entries.
@resultBuilder
public enum DestinationsBuilder {
    /* blocks, conditions and loops */
}

/// Registers one route type's screen inside a coordinator.
///
/// Conformances:
/// - `Destinations`, so it can be listed in a coordinator's destinations.
/// - `R: Route`: the route type this works with.
/// - `Content: Screen`: the route's screen, a SwiftUI view or a view controller.
public struct Destination<R: Route, Content: Screen>: Destinations {
    /// `presentation` is how `router.show(_:)` shows the route. Default: `nil`, a push.
    public init(
        _ type: R.Type,
        presentation: PresentationStyle? = nil,
        @ScreenBuilder _ content: @escaping (R) -> Content
    )

    /// The same, and also hands the screen the stack's navigator for its view model.
    public init(
        _ type: R.Type,
        presentation: PresentationStyle? = nil,
        @ScreenBuilder _ content: @escaping (R, StackNavigator) -> Content
    )
}
```

A tab coordinator adds the screen for each tab:

```swift
// What `Waypoint` adds to `TabCoordinator`. The tab type and the router are in the core.
//
// Conformances:
// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol TabCoordinator: AnyObject {
    /// Conformances:
    /// - `View`: a tab's stack coordinator's `view`, with its label.
    associatedtype TabContent: View
    /// Conformances:
    /// - `TabRenderer`: what draws this coordinator. Default: `DefaultTabRenderer`.
    associatedtype Renderer: TabRenderer = DefaultTabRenderer

    /// The tabs, drawn by `Renderer`. Default: filled in by Waypoint.
    var view: Renderer { get }

    /// The screen for one tab, usually one of the coordinator's stack coordinators' `view`.
    /// How Waypoint learns each tab's coordinator before drawing is designed in #59.
    @ViewBuilder func makeTabFlow(for tab: Tab) -> TabContent
}
```

A flow that stands for a route is a `Flow` entry in `destinations`. Its factory builds the flow's coordinator, and its handler receives the result (#60):

```swift
/// Registers a route that opens a child flow, and the handler for the flow's result.
///
/// Conformances:
/// - `Destinations`, so it can be listed in a coordinator's destinations.
/// - `R: Route`: the route that stands for the flow.
/// - `C: FlowCoordinator`: the flow's coordinator.
public struct Flow<R: Route, C: FlowCoordinator>: Destinations {
    /// `presentation` is how `router.show(_:)` shows the flow. Default: `nil`, a push.
    public init(
        _ type: R.Type,
        presentation: PresentationStyle? = nil,
        _ make: @escaping @MainActor (R) -> C,
        onResult: @escaping @MainActor (FlowResult<C.Output>) -> Void
    )
}
```

An entry with no `onResult:`, whose result goes to a call that awaits the route, is designed with #60, together with how that call is written. Until then every `Flow(...)` entry names its handler, so no result is lost.

`RootCoordinator` and `FlowCoordinator` follow the same shape, each with its own router and renderer. Which requirements live in `WaypointCore`, which has no UI, and which in `Waypoint`, which adds the screens, is settled in #59. The core part stays testable on Linux. The `presentation:` parameter declares how `router.show(_:)` shows the route, built in #12: see "Declared presentation" in the core's presentation article.

### A coordinator's view

Every coordinator has a `view`: the whole flow, drawn by its renderer. `ShopCoordinator().view` is the shop's stack with all its screens. A parent shows a child's `view` wherever the child's flow goes, and an existing app shows a Waypoint flow anywhere the same way (#151).

`viewController` is a `UIHostingController` around `view`, for any UIKit place that needs a controller. `viewController`, view controller screens and the UIKit renderers exist only where UIKit does: their code sits behind `#if canImport(UIKit)`, so the package still builds on macOS and Linux. With the UIKit renderer inside, the screens are still drawn by a real `UINavigationController`.

SwiftUI reads `view` again on every update. The renderer's state is kept for each coordinator, like its router, so every read draws the same stack and the user never loses their place. Drawing the same coordinator in two places at once reports it in debug and draws only the first.

### The window

The window is the one place where the kind of app shows, because each entry point needs its own type. Both entries draw the app coordinator's `view`:

```swift
// SwiftUI `App`: one app coordinator per window, made by Waypoint.
WindowGroup {
    WaypointRoot {
        AppCoordinator(services: services)
    }
}

// UIKit scene delegate: the scene already exists once per window.
window = app.makeWindow(for: scene, options: options)
```

- `WaypointRoot { … }` makes the app coordinator once for each window and keeps it, sends incoming links to its inbox and draws its `view`. A plain `WindowGroup { app.view }` would share one coordinator between windows, or make a new one each time SwiftUI rebuilds the scene.
- `makeWindow(for:options:)` makes the window, sets its root to the app coordinator's `viewController`, and hands the links a cold launch brings to the inbox.

See <doc:ExampleFlows> for a SwiftUI app and <doc:ExampleFlowsInUIKit> for a UIKit app. The coordinators are the same in both.

### Renderers

A renderer is a SwiftUI view that conforms to a protocol Waypoint owns, one for each kind of coordinator. It draws its coordinator's router and reports what the user changes, such as a swipe back, a sheet dragged down or a tab tap.

```swift
/// Draws a stack coordinator.
///
/// Conformances:
/// - `View`, because a renderer is what the coordinator's `view` returns.
@MainActor
public protocol StackRenderer: View {
    init(coordinator: some StackCoordinator)
}

// `RootRenderer`, `TabRenderer` and `FlowRenderer` follow the same shape.
```

| Kind | SwiftUI renderer | UIKit renderer |
|---|---|---|
| Root | `SwiftUIRootRenderer` | `UIKitRootRenderer` (#220) |
| Tabs | `SwiftUITabRenderer`, a `TabView` | `UIKitTabRenderer`, a `UITabBarController` (#50) |
| Stack | `SwiftUIStackRenderer`, a `NavigationStack` | `UIKitStackRenderer`, a `UINavigationController` (#14) |
| Presented flow | `SwiftUIFlowRenderer` | `UIKitFlowRenderer` (#49) |

Both renderers of a kind read the same router and follow the same contract with it. Switching renderers never changes how navigation behaves, only how it is drawn. `SwiftUIStackRenderer` draws with `WaypointStack`, so everything <doc:SwiftUIRenderer> says about stacks holds for it.

**Defaults.** Each kind's default renderer (`DefaultStackRenderer` and the others) picks the best renderer for the system the app runs on, once, when the coordinator is first drawn, so the choice never changes while the app runs. "Best" comes from evidence: the problems each renderer is known to have for each kind and system, measured on real devices and simulators. Today every default is the SwiftUI renderer, on every system. A default changes only in a minor release, with a changelog line that names the problems behind it. In 0.x any release may change one, so an app that wants no change sets its renderers itself.

### Choosing a renderer

Choose once for the whole app, in the root's `NavigationConfiguration`:

```swift
let configuration = NavigationConfiguration(renderers: .init(stack: .uiKit, tab: .swiftUI))
let router = RootRouter(AppRoot.login, configuration: configuration)
```

`NavigationConfiguration` lives in `WaypointCore`, which has no UI, so the core keeps the choice as plain values: `.default`, `.swiftUI` and `.uiKit`. `.custom(MyStackRenderer.self)`, which names a renderer type, comes from `Waypoint`. How the core stores it without knowing the type is settled in #59.

Or choose for one coordinator, by declaring its `Renderer`:

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
final class ScannerCoordinator: StackCoordinator {
    typealias Renderer = UIKitStackRenderer

    var root: some Screen {
        ScannerViewController()
    }

    var destinations: some Destinations {
        Destination(ScanResultRoute.self) { route in
            ScanResultView(code: route.code)
        }
    }
}
```

The choice for a place is made in this order:

1. Waypoint's own rule for the place, where it has one. In 0.x, a Waypoint stack inside the app's own `NavigationStack` is always drawn by the UIKit stack renderer. A coordinator that declares another renderer there is still drawn that way, and the choice is reported in debug. Because `view` keeps the declared type, the declared renderer hands its drawing to the UIKit stack renderer in that place; how is designed in #151.
2. The coordinator's own `Renderer`.
3. The app-wide choice.
4. Waypoint's default.

A pushed child flow shares its parent's stack, so its parent's renderer draws it. A pushed child that declares a renderer has it ignored, and that is reported in debug.

The issue kinds for these reports, such as `coordinatorDrawnTwice`, `rendererNotSupportedHere` and `rendererIgnoredForPushedFlow`, are added to `NavigationIssue.Kind` when #59 builds them.

### Mixing SwiftUI and UIKit

Renderers of different kinds work in one tree: a UIKit tab bar can hold SwiftUI stacks, and a SwiftUI sheet can hold a UIKit stack. The presenting renderer makes the presentation, a sheet or a cover, and the child's renderer draws what is inside it. Screens of either kind work in either renderer, so an app moves a flow from one to the other one screen at a time.

**The environment.** Screens hosted by the UIKit renderer receive the app's SwiftUI environment where the renderer sits, and redraw when it changes. Waypoint adds its own values for each screen (its router, flow and settings), so the property wrappers in <doc:NavigatingFromViewsAndViewModels> work in both renderers.

**Screen chrome.** Titles, toolbars, the back button, search and `tabBarOnPushedScreens(_:motion:)` follow a contract that both renderers are tested against (#253). Inside a `UINavigationController`, iOS doesn't show every SwiftUI modifier on its own: a prototype of the UIKit stack renderer (#250) didn't show a SwiftUI screen's `navigationTitle`, and on iOS 27 its `toolbar` and `searchable` either. Until #253 closes that gap, a row a renderer can't support counts against it when defaults are chosen, and reports an issue in debug, never a silent difference. The defaults stay SwiftUI meanwhile.

The journey log names each screen in both renderers: a SwiftUI screen by its view, a controller screen by its type name. A route with no destination shows the same missing-destination screen in both.

### Your own renderer

A renderer of your own is any view that conforms to the kind's protocol. Choose it app-wide with `.custom(MyStackRenderer.self)`, or per coordinator with `typealias Renderer = MyStackRenderer`, the same way as the built-in ones. The renderer protocols and the calls a renderer makes on its router are public.

Every renderer, built-in or your own, passes the same two suites (#252): the sync-contract suite in `WaypointTesting`, which runs on Linux, and the drawing suite in `WaypointRendererTesting`, which runs on a simulator.

What each built-in renderer does in its own framework is in <doc:SwiftUIRenderer> and <doc:UIKitRenderer>.
