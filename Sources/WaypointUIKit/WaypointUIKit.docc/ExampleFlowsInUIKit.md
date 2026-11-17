# Five example flows in UIKit

Login, tabs, a detail push, a sheet and a deep link, with view controllers.

## Overview

These are the same five flows as the SwiftUI examples. The routes, routers and coordinators' logic don't change, only the screens do. The app coordinator has the same rules in both. That is what lets an app move a flow from one renderer to the other, one screen at a time.

### 1. Login, then the main tabs

The app coordinator owns the app's navigation, as in the SwiftUI example. The scene delegate creates it, hands it to the window and forwards what the OS hands it.

```swift
// Conformances:
// - `UIWindowSceneDelegate`, so UIKit hands it the scene's window and its links.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let app = AppCoordinator()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        window?.rootViewController = WaypointRootViewController(app)
        app.links?.receive(connectionOptions: options)
    }
}

// Conformances:
// - `UIKitRootCoordinator`, so `WaypointRootViewController` can draw it.
final class AppCoordinator: UIKitRootCoordinator {
    let router = RootRouter(AppRoot.login)
    let links: LinkInbox? = LinkInbox(domains: LinkDomains(hosts: ["example.com"], schemes: ["myshop"]))
    let tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)
    private(set) lazy var shop = ShopCoordinator(router: tabs.router(for: .shop))

    func makeViewController(for root: AppRoot) -> UIViewController {
        switch root {
        case .login:
            LoginViewController(onLoggedIn: { [weak self] in self?.didLogIn() })
        case .main:
            makeTabs()
        }
    }

    func didLogIn() {
        router.switch(to: .main)
        links?.isReady = true
    }

    func didLogOut() {
        links?.isReady = false
        router.switch(to: .login)
    }
}
```

### 2. Tabs, one stack each

```swift
extension AppCoordinator {
    func makeTabs() -> UIViewController {
        WaypointTabBarController(router: tabs) { [tabs, shop] tab in
            switch tab {
            case .home:
                WaypointNavigationController(router: tabs.router(for: .home), root: HomeViewController())
            case .shop:
                WaypointNavigationController(shop)
            case .profile:
                WaypointNavigationController(router: tabs.router(for: .profile), root: ProfileViewController())
            }
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
extension SceneDelegate {
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        app.links?.receive(contexts)
    }
}
```

The matcher, the plans and the link policy are the ones from the SwiftUI example. They live in `WaypointCore`, so both renderers use the same code.
