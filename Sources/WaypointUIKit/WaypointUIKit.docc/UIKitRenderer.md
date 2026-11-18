# The UIKit renderer

Show stacks, sheets, tabs and roots with UIKit view controllers.

## Overview

> Note: Draft until #14. The API in this article is planned, not built, and can still change when #14 lands.

The UIKit renderer watches routers and turns each change into the matching UIKit call. A stack change of any size is one `setViewControllers(_:animated:)` call with one animation, and view controllers for the unchanged start of the path are reused. Changes that arrive during a transition wait until it ends, then are applied together against the latest state.

Within one update, the renderer dismisses first, then changes stacks, then presents. Swipe back, the back button, its long-press menu, sheet drags and tab taps are reported back to the routers.

View controllers navigate through injection: the coordinator or the destination closure passes them a `StackNavigator` or a `FlowNavigator`. There are no property wrappers in UIKit.

### Stacks

```swift
/// A navigation controller driven by a `StackRouter`.
@MainActor
public final class WaypointNavigationController: UINavigationController {
    /// The router this controller draws.
    public let router: StackRouter

    /// Creates a navigation controller that draws the router's stack over a root screen.
    public init(router: StackRouter, root: UIViewController)

    /// Shows a view controller when a route of type `R` is pushed or presented.
    public func destination<R: Route>(
        _ type: R.Type,
        _ make: @escaping @MainActor (R) -> UIViewController
    )

    /// The same, and also hands the view controller a navigator.
    public func destination<R: Route>(
        _ type: R.Type,
        _ make: @escaping @MainActor (R, StackNavigator) -> UIViewController
    )

    /// Defines an app-specific sheet size, used by `SheetDetent.custom(name)`.
    public func sheetDetent(_ name: String, _ detent: UISheetPresentationController.Detent)
}
```

A route with no destination never crashes. Debug builds push a "No destination for …" screen that names the route and the fix, and release builds refuse the push.

> Note: Stack containers are changing. Waypoint will create the container itself wherever a coordinator starts a new stack: the app's root, a presented flow, a tab's root, or a flow shown from existing app code. Apps show a coordinator and never create or wire a container. Existing UIKit code that is not a coordinator will be able to show a flow and get its result back. A pushed child coordinator shares its parent's stack. A route's destination will be able to return a SwiftUI view or a UIKit view controller in either renderer. Apps still push routes, never views. Tracked in #151.

### Coordinators

```swift
/// A stack coordinator that draws with UIKit.
///
/// Conformances:
/// - `StackCoordinator`: it adds screen building to a stack coordinator.
@MainActor
public protocol UIKitStackCoordinator: StackCoordinator {
    /// The flow's screens, by route type.
    @UIKitDestinationsBuilder var destinations: UIKitDestinations { get }

    /// The flow's first screen.
    func makeRootViewController() -> UIViewController
}

/// Registers one route type's view controller inside a coordinator.
///
/// Conformances:
/// - `R: Route`: the route type this works with.
public struct UIKitDestination<R: Route> {
    public init(_ type: R.Type, _ make: @escaping @MainActor (R) -> UIViewController)
    public init(
        _ type: R.Type,
        _ make: @escaping @MainActor (R, StackNavigator) -> UIViewController
    )
}

extension WaypointNavigationController {
    /// Draws a coordinator's flow.
    public convenience init<C: UIKitStackCoordinator>(_ coordinator: C)
}
```

```swift
// Conformances:
// - `UIKitStackCoordinator`, so `WaypointNavigationController` can draw it.
final class ShopCoordinator: UIKitStackCoordinator {
    let router = StackRouter()

    var destinations: UIKitDestinations {
        UIKitDestination(ProductRoute.self) { ProductViewController(id: $0.id) }
        UIKitDestination(CartRoute.self) { _ in CartViewController() }
    }

    func makeRootViewController() -> UIViewController {
        ProductListViewController(onSelect: { [weak self] in self?.showProduct(id: $0) })
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }
}

let shop = ShopCoordinator()
let navigationController = WaypointNavigationController(shop)
```

A whole app shows its flows through an app coordinator, not by setting a window's root in a lifecycle method. See "Tabs and roots" below.

### Sheets and full-screen covers

Sheet sizes come from the presentation's `SheetOptions` and map to `UISheetPresentationController.Detent`: `.medium` and `.large` directly, `.fraction` and `.height` as custom detents, and `.custom(name)` as the detent registered for that name. `.fitsContent` is a custom detent sized to the content: its `preferredContentSize` when it sets one, or else its Auto Layout height at the sheet's width, capped at `fitsContentLimit`. When the height changes, the sheet animates to it. Taller content scrolls in its own scroll view, such as a table, or in one the renderer adds. When the user drags a sheet to another size, the selected detent is reported back to the router.

### Tabs and roots

```swift
/// An app coordinator that draws with UIKit.
///
/// Conformances:
/// - `RootCoordinator`: it adds a view controller for each root to an app coordinator.
@MainActor
public protocol UIKitRootCoordinator: RootCoordinator {
    /// Builds the flow for one root.
    func makeFlow(for root: Root) -> UIViewController
}

extension WaypointRootViewController {
    /// Draws an app coordinator's flow, and attaches its root router to its link inbox.
    public convenience init<C: UIKitRootCoordinator>(_ coordinator: C) where Root == C.Root
}
```

```swift
/// A tab bar controller driven by a `TabRouter`.
///
/// Conformances:
/// - `Tab: NavigationTab`, the app's tab type.
@MainActor
public final class WaypointTabBarController<Tab: NavigationTab>: UITabBarController {
    /// `make` builds each tab's controller once, usually a `WaypointNavigationController`
    /// for `router.router(for: tab)`, with its tab bar item set.
    public init(router: TabRouter<Tab>, make: @escaping @MainActor (Tab) -> UIViewController)
}

/// A container that shows whichever root a `RootRouter` is showing,
/// with a cross-fade when it switches.
///
/// Conformances:
/// - `Root: NavigationRoot`, the app's root type.
@MainActor
public final class WaypointRootViewController<Root: NavigationRoot>: UIViewController {
    public init(router: RootRouter<Root>, make: @escaping @MainActor (Root) -> UIViewController)
}
```

### Mixing UIKit and SwiftUI

A coordinator can conform to both `UIKitStackCoordinator` and `SwiftUIStackCoordinator`. Whichever renderer shows the flow asks for its own kind of screens.

- **A UIKit stack shows a SwiftUI screen:** register a destination that returns `UIHostingController(rootView: ProductView(...))`.
- **A UIKit flow presents a SwiftUI flow:** `router.present(SwiftUIFilterCoordinator(), style: .sheet)`. The renderer hosts the SwiftUI stack, and swipe back and sheet drags inside it are reported to its router.
- **A SwiftUI flow presents a UIKit flow:** the SwiftUI renderer hosts the UIKit coordinator's navigation controller in the same way.

### Incoming links

```swift
extension LinkInbox {
    /// Cold launch: reads every URL, user activity and shortcut in the options at once.
    public func receive(connectionOptions: UIScene.ConnectionOptions)
    /// Receives URLs the scene opened.
    public func receive(_ contexts: Set<UIOpenURLContext>)
    /// Receives a universal link or handoff activity.
    public func receive(_ activity: NSUserActivity)
    /// Returns whether the shortcut was handled, for the completion handler.
    public func receive(_ item: UIApplicationShortcutItem) -> Bool
    /// Attaches the root router the links are applied to.
    /// `WaypointRootViewController(app)` does this for you.
    public func attach<Root>(_ root: RootRouter<Root>)
}
```

Most apps don't call the inbox directly. The app coordinator gives the scene delegate one-line forwards, so lifecycle methods hold no navigation logic:

```swift
extension UIKitRootCoordinator {
    /// Makes the window for a new scene, shows the app coordinator's flow in it,
    /// and hands its link inbox every URL, user activity and shortcut in `options`.
    ///
    /// Returns `nil` if `scene` is not a window scene.
    public func makeWindow(for scene: UIScene, options: UIScene.ConnectionOptions) -> UIWindow?

    /// Hands links to the app coordinator's inbox. Does nothing if `links` is `nil`.
    public func receive(_ contexts: Set<UIOpenURLContext>)
    /// Forwards a universal link or handoff activity to the link inbox.
    public func receive(_ activity: NSUserActivity)
    /// Returns whether the shortcut was handled, for the completion handler.
    public func receive(_ item: UIApplicationShortcutItem) -> Bool
}
```

The scene delegate in <doc:ExampleFlowsInUIKit> uses only these. Where to go next is always the app coordinator's call.
