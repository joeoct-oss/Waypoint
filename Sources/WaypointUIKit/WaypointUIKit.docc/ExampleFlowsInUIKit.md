# Five example flows in UIKit

Login, tabs, a detail push, a sheet and a deep link, with view controllers.

## Overview

These are the same five flows as the SwiftUI examples. The routes, routers and coordinators' logic don't change, only the screens do. That is what lets an app move a flow from one renderer to the other, one screen at a time.

### 1. Login, then the main tabs

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    let root = RootRouter(AppRoot.login)
    let tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)

    window?.rootViewController = WaypointRootViewController(router: root) { current in
        switch current {
        case .login:
            LoginViewController(onLoggedIn: { root.switch(to: .main) })
        case .main:
            makeTabs(tabs)
        }
    }
    inbox.attach(root)
    inbox.receive(connectionOptions: options)
}
```

### 2. Tabs, one stack each

```swift
func makeTabs(_ tabs: TabRouter<MainTab>) -> UIViewController {
    WaypointTabBarController(router: tabs) { tab in
        switch tab {
        case .home:
            WaypointNavigationController(router: tabs.router(for: .home), root: HomeViewController())
        case .shop:
            WaypointNavigationController(ShopCoordinator(router: tabs.router(for: .shop)))
        case .profile:
            WaypointNavigationController(router: tabs.router(for: .profile), root: ProfileViewController())
        }
    }
}
```

### 3. A detail push

```swift
// Conformances:
// - `UIKitStackCoordinator`, so `WaypointNavigationController` can draw it.
// - `NavigationFlow`, so routes can name it as their flow.
final class ShopCoordinator: UIKitStackCoordinator, NavigationFlow {
    let router: StackRouter
    init(router: StackRouter) { self.router = router }

    func makeRootViewController() -> UIViewController {
        ProductListViewController(onSelect: { [router] in router.push(ProductRoute(id: $0)) },
                                  onFilter: { [weak self] in self?.showFilters() })
    }

    var destinations: UIKitDestinations {
        UIKitDestination(ProductRoute.self) { route, navigation in
            ProductViewController(model: ProductModel(id: route.id, navigation: navigation))
        }
        UIKitDestination(CartRoute.self) { _ in CartViewController() }
    }
}
```

`ProductModel` is the same view model the SwiftUI example uses. It imports only `WaypointCore`.

### 4. A sheet that returns a result

The filter flow here is the SwiftUI `FilterCoordinator`, presented from UIKit. The renderer hosts it, and the result comes back the same way.

```swift
extension ShopCoordinator {
    func showFilters() {
        router.present(FilterCoordinator(), style: .sheet(detents: [.medium, .large])) { [weak self] result in
            if case .finished(let filter) = result { self?.apply(filter) }
        }
    }
}
```

### 5. A deep link

```swift
func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    inbox.receive(contexts)
}
```

The matcher, the plans and the link policy are the ones from the SwiftUI example. They live in `WaypointCore`, so both renderers use the same code.
