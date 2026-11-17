# The UIKit renderer

Show stacks, sheets, tabs and roots with UIKit view controllers.

## Overview

The UIKit renderer watches routers and turns each change into the matching UIKit call. A stack change of any size is one `setViewControllers(_:animated:)` call with one animation, and view controllers for the unchanged start of the path are reused. Changes that arrive during a transition wait until it ends, then are applied together against the latest state.

Within one update, the renderer dismisses first, then changes stacks, then presents. Swipe back, the back button, its long-press menu, sheet drags and tab taps are reported back to the routers.

View controllers navigate through injection: the coordinator or the destination closure passes them a `StackNavigator` or a `FlowNavigator`. There are no property wrappers in UIKit.

### Stacks

```swift
/// A navigation controller driven by a `StackRouter`.
@MainActor
public final class WaypointNavigationController: UINavigationController {
    public init(router: StackRouter, root: UIViewController)

    public let router: StackRouter

    /// Shows a view controller when a route of type `R` is pushed or presented.
    public func destination<R: Route>(_ type: R.Type,
                                      _ make: @escaping @MainActor (R) -> UIViewController)

    /// The same, and also hands the view controller a navigator.
    public func destination<R: Route>(_ type: R.Type,
                                      _ make: @escaping @MainActor (R, StackNavigator) -> UIViewController)

    /// Defines an app-specific sheet size, used by `SheetDetent.custom(name)`.
    public func sheetDetent(_ name: String, _ detent: UISheetPresentationController.Detent)
}
```

A route with no destination never crashes. Debug builds push a "No destination for …" screen that names the route and the fix, and release builds refuse the push.

### Coordinators

```swift
/// A stack coordinator that draws with UIKit.
///
/// Conformances:
/// - `StackCoordinator`: it adds screen building to a stack coordinator.
@MainActor
public protocol UIKitStackCoordinator: StackCoordinator {
    /// The flow's first screen.
    func makeRootViewController() -> UIViewController
    /// The flow's screens, by route type.
    @UIKitDestinationsBuilder var destinations: UIKitDestinations { get }
}

/// Registers one route type's view controller inside a coordinator.
///
/// Conformances:
/// - `R: Route`: the route type this works with.
public struct UIKitDestination<R: Route> {
    public init(_ type: R.Type, _ make: @escaping @MainActor (R) -> UIViewController)
    public init(_ type: R.Type, _ make: @escaping @MainActor (R, StackNavigator) -> UIViewController)
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

    func makeRootViewController() -> UIViewController {
        ProductListViewController(onSelect: { [router] in router.push(ProductRoute(id: $0)) })
    }

    var destinations: UIKitDestinations {
        UIKitDestination(ProductRoute.self) { ProductViewController(id: $0.id) }
        UIKitDestination(CartRoute.self) { _ in CartViewController() }
    }
}

let shop = ShopCoordinator()
let navigationController = WaypointNavigationController(shop)
```

A whole app shows its flows through an app coordinator, not by setting a window's root in a lifecycle method. See "Tabs and roots" below.

### Sheets and full-screen covers

Sheet sizes come from the presentation's `SheetOptions` and map to `UISheetPresentationController.Detent`: `.medium` and `.large` directly, `.fraction` and `.height` as custom detents, and `.custom(name)` as the detent registered for that name. When the user drags a sheet to another size, the selected detent is reported back to the router.

### Tabs and roots

```swift
/// An app coordinator that draws with UIKit.
///
/// Conformances:
/// - `RootCoordinator`: it adds a view controller for each root to an app coordinator.
@MainActor
public protocol UIKitRootCoordinator: RootCoordinator {
    /// The screen or flow for one root.
    func makeViewController(for root: Root) -> UIViewController
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
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
@MainActor
public final class WaypointTabBarController<Tab: Hashable & Codable & Sendable>: UITabBarController {
    /// `make` builds each tab's controller once, usually a `WaypointNavigationController`
    /// for `router.router(for: tab)`, with its tab bar item set.
    public init(router: TabRouter<Tab>, make: @escaping @MainActor (Tab) -> UIViewController)
}

/// A container that shows whichever root a `RootRouter` is showing,
/// with a cross-fade when it switches.
///
/// Conformances:
/// - `Root: Hashable`, to compare roots.
/// - `Root: Codable`, so the current root is saved and restored.
/// - `Root: Sendable`, so root events can leave the main actor.
@MainActor
public final class WaypointRootViewController<Root: Hashable & Codable & Sendable>: UIViewController {
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
    public func receive(_ contexts: Set<UIOpenURLContext>)
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
    public func receive(_ activity: NSUserActivity)
    /// Returns whether the shortcut was handled, for the completion handler.
    public func receive(_ item: UIApplicationShortcutItem) -> Bool
}
```

The scene delegate in <doc:ExampleFlowsInUIKit> uses only these. Where to go next is always the app coordinator's call.
