# Five example flows in UIKit

Login, tabs, a detail push, a sheet and a deep link, in a UIKit app with view controllers.

## Overview

> Note: Draft until #59. The API in this article is planned, not built, and can still change: coordinators (#59), the UIKit stack renderer (#14), and the UIKit half of roots and windows (#220).

These are the same five flows as in <doc:ExampleFlows>, in an app with a scene delegate. The routes, the routers and the coordinators don't change. Only two things do: the window comes from the scene delegate, and the screens are view controllers. That is what lets an app move a flow from SwiftUI to UIKit, or back, one screen at a time.

### 1. Login, then the main tabs

The app coordinator is the same `AppCoordinator` as in the SwiftUI example. The scene delegate holds no logic: each lifecycle method is one line that hands the system's input to the coordinator.

```swift
// Conformances:
// - `UIResponder`, because UIKit requires a scene delegate to be a responder.
// - `UIWindowSceneDelegate`, so UIKit hands it the scene's window and its links.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // `var` because `UIWindowSceneDelegate` requires a settable window.
    var window: UIWindow?
    let app = AppCoordinator()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) {
        window = app.makeWindow(for: scene, options: options)
    }

    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        app.receive(contexts)
    }

    func scene(_ scene: UIScene, continue activity: NSUserActivity) {
        app.receive(activity)
    }
}
```

`makeWindow(for:options:)` sets the window's root to the app coordinator's `viewController` and hands the links a cold launch brings to its inbox. The scene already exists once for each window, so each window gets its own app coordinator.

The login screen can be a view controller. Only the login coordinator's `root` changes:

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
final class LoginCoordinator: StackCoordinator {
    let onLoggedIn: () -> Void

    var root: some Screen {
        LoginViewController(onLoggedIn: onLoggedIn)
    }

    var destinations: some Destinations { }

    init(onLoggedIn: @escaping () -> Void) {
        self.onLoggedIn = onLoggedIn
    }
}
```

### 2. Tabs, one stack each

`MainTabsCoordinator` is the same as in the SwiftUI example. Its tabs are drawn by the default tab renderer, which is SwiftUI's until the UIKit tab renderer lands (C4, #50). Each tab shows its stack coordinator's `view`, drawn by whichever renderer that coordinator uses.

### 3. A detail push

The shop draws its stack with a `UINavigationController` by choosing `UIKitStackRenderer`. Its screens are view controllers, and a SwiftUI screen can sit next to them:

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
// - `NavigationFlow`, so routes can name it as their flow.
final class ShopCoordinator: StackCoordinator, NavigationFlow {
    typealias Renderer = UIKitStackRenderer

    private static let filterDetents: [SheetDetent] = [.medium, .large]

    var root: some Screen {
        ProductListViewController(
            onSelect: { [weak self] in self?.showProduct(id: $0) },
            onFilter: { [weak self] in self?.showFilters() }
        )
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { route, navigation in
            ProductViewController(model: ProductModel(id: route.id, navigation: navigation))
        }
        Destination(CartRoute.self) { _ in
            CartView()
        }
        Flow(FilterRoute.self, presentation: .sheet(detents: Self.filterDetents)) { _ in
            FilterCoordinator()
        } onResult: { [weak self] result in
            self?.filterEnded(result)
        }
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }
}
```

`ProductModel` is the same view model the SwiftUI example uses. It imports only `WaypointCore`. `CartView` is the SwiftUI cart, hosted by the renderer in a `UIHostingController`.

Leave out `typealias Renderer` to use the default stack renderer, or choose the UIKit stack renderer for every stack in the root's `NavigationConfiguration`. See <doc:Renderers>.

### 4. A sheet that returns a result

The filter flow is the same `FilterCoordinator`, with SwiftUI screens, presented from the UIKit stack. `showFilters()` and `filterEnded(_:)` are the same functions as in the SwiftUI example, and the result comes back the same way.

### 5. A deep link

The scene delegate from the first example already forwards URLs and user activities to the app coordinator, and `makeWindow(for:options:)` hands it the links a cold launch brings. The inbox holds them until `showMainFlow()` calls `links?.markReady()`. Nothing else is needed in the scene delegate.

The matcher, the plans and the link policy are the ones from the SwiftUI example. They live in `WaypointCore`, so every renderer uses the same code.
