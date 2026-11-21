# The UIKit renderer

Draw stacks, sheets, tabs and roots with UIKit view controllers.

## Overview

> Note: Draft until #59 and #14. The API in this article is planned, not built, and can still change. The UIKit stack renderer is built in C3 (#14). UIKit tabs, presented flows and roots follow in C4 (#50, #49, #220).

The UIKit renderers draw the same coordinators as the SwiftUI ones, with UIKit's own containers: a `UINavigationController`, sheets presented by a `UISheetPresentationController`, and a `UITabBarController`. An app chooses them app-wide or for one coordinator, and the coordinator's code doesn't change. See <doc:Renderers> for how a renderer is chosen.

Each UIKit renderer is a SwiftUI view that wraps its container in a `UIViewControllerRepresentable`, so a coordinator's `view` and `viewController` work the same whichever renderer draws it. Screens can be view controllers or SwiftUI views: a SwiftUI screen is hosted in a `UIHostingController` and receives the app's environment.

The renderer watches the router and turns each change into the matching UIKit call. A stack change of any size is one `setViewControllers(_:animated:)` call with one animation, and view controllers for the unchanged start of the path are reused. Changes that arrive during a transition wait until it ends, then are applied together against the latest state. Within one update, the renderer dismisses first, then changes stacks, then presents. Swipe back, the back button, its long-press menu, sheet drags and tab taps are reported back to the router.

View controllers navigate through injection: the coordinator or the destination closure passes them a `StackNavigator` or a `FlowNavigator`. There are no property wrappers in UIKit. SwiftUI screens inside the UIKit renderer keep theirs.

### Stacks

`UIKitStackRenderer` draws a stack coordinator with a `UINavigationController`. Choose it for one coordinator by declaring its `Renderer`:

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
final class ShopCoordinator: StackCoordinator {
    typealias Renderer = UIKitStackRenderer

    var root: some Screen {
        ProductListViewController(onSelect: { [weak self] in self?.showProduct(id: $0) })
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { route in
            ProductViewController(id: route.id)
        }
        Destination(ReviewsRoute.self) { route in
            ReviewsView(productID: route.productID)
        }
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }
}

let shop = ShopCoordinator()
let navigation = shop.viewController
```

`ReviewsView` is a SwiftUI view, hosted by the renderer. `shop.viewController` is a `UIHostingController` around `shop.view`, with a real `UINavigationController` inside.

```swift
/// Draws a stack coordinator with a `UINavigationController`.
///
/// Conformances:
/// - `StackRenderer`, so a stack coordinator can choose it.
@MainActor
public struct UIKitStackRenderer: StackRenderer {
    public init(coordinator: some StackCoordinator)
}

extension View {
    /// Defines an app-specific sheet size for the UIKit renderers, used by
    /// `SheetDetent.custom(name)`.
    public func sheetDetent(_ name: String, _ detent: UISheetPresentationController.Detent) -> some View
}
```

A route with no destination never crashes. The renderer shows the same missing-destination screen as the SwiftUI renderer: debug builds name the route and the fix, and release builds show a blank screen.

**Titles and toolbars.** Today the UIKit stack renderer doesn't show a SwiftUI screen's `navigationTitle`, and on iOS 27 its `toolbar` and `searchable` either. A view controller screen sets its own `navigationItem` as usual. Closing that gap is #253. Until then the default stack renderer stays SwiftUI.

### Sheets and full-screen covers

Sheet sizes come from the presentation's `SheetOptions` and map to `UISheetPresentationController.Detent`: `.medium` and `.large` directly, `.fraction` and `.height` as custom detents, and `.custom(name)` as the detent registered for that name. `.fitsContent` is a custom detent sized to the content: its `preferredContentSize` when it sets one, or else its Auto Layout height at the sheet's width, capped at `fitsContentLimit`. When the height changes, the sheet animates to it. Taller content scrolls in its own scroll view, such as a table, or in one the renderer adds. When the user drags a sheet to another size, the selected detent is reported back to the router.

A presented flow is drawn by `UIKitFlowRenderer` when the flow chooses it (C4, #49). Until then a presented flow's default is the SwiftUI renderer, and a UIKit stack presented inside it is still drawn by `UIKitStackRenderer`.

### Tabs and roots

`UIKitTabRenderer` draws a tab coordinator with a `UITabBarController` (C4, #50), and `UIKitRootRenderer` draws the app coordinator's roots, with a cross-fade when it switches (C4, #220). Each tab hosts its stack coordinator's `view`, drawn by whichever renderer that coordinator uses. Tab labels written with SwiftUI's `.tabItem` work only in the SwiftUI tab renderer. How a tab coordinator gives its labels to the UIKit one is designed in #50.

### A UIKit app

A UIKit app uses the same coordinators as a SwiftUI app. Only the window differs: the scene delegate asks the app coordinator for its window, and each lifecycle method hands the system's input to it in one line.

```swift
extension RootCoordinator {
    /// Makes the window for a new scene, sets its root to the app coordinator's
    /// `viewController`, and hands its link inbox every URL, user activity and
    /// shortcut in `options`.
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

### Showing a flow from existing UIKit code

Existing UIKit code that isn't a coordinator shows a Waypoint flow through the coordinator's `viewController`, and gets the flow's result back. How it fits inside the app's own navigation controller is designed in #151.

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
    /// `makeWindow(for:options:)` does this for you.
    public func attach<Root>(_ root: RootRouter<Root>)
}
```

Most apps don't call the inbox directly: `makeWindow(for:options:)` and the `receive(_:)` forwards above do it.
