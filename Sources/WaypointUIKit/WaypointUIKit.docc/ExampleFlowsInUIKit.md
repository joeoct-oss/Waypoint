# Five example flows in UIKit

Login, tabs, a detail push, a sheet and a deep link, with view controllers.

## Overview

These are the same five flows as the SwiftUI examples. The routes, routers and coordinators' logic don't change, only the screens do. The app coordinator has the same rules in both. That is what lets an app move a flow from one renderer to the other, one screen at a time.

### 1. Login, then the main tabs

The app coordinator owns the app's navigation, as in the SwiftUI example. The scene delegate holds no logic: each lifecycle method is one line that hands the OS's input to the coordinator.

```swift
// Conformances:
// - `UIResponder`, because UIKit requires a scene delegate to be a responder.
// - `UIWindowSceneDelegate`, so UIKit hands it the scene's window and its links.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let app = AppCoordinator()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        window = app.makeWindow(for: scene, options: options)
    }

    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        app.receive(contexts)
    }

    func scene(_ scene: UIScene, continue activity: NSUserActivity) {
        app.receive(activity)
    }
}

// Conformances:
// - `UIKitRootCoordinator`, so `WaypointRootViewController` can draw it.
final class AppCoordinator: UIKitRootCoordinator {
    let router = RootRouter(AppRoot.login)
    let links: LinkInbox? = LinkInbox(domains: LinkDomains(hosts: ["example.com"], schemes: ["myshop"]))
    let tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)
    private(set) lazy var shop = ShopCoordinator(router: tabs.router(for: .shop))

    func makeFlow(for root: AppRoot) -> UIViewController {
        switch root {
        case .login:
            makeLoginFlow()
        case .main:
            makeMainTabsFlow()
        }
    }

    func makeLoginFlow() -> UIViewController {
        LoginViewController(onLoggedIn: { [weak self] in self?.showMainFlow() })
    }

    func showMainFlow() {
        router.switch(to: .main)
        links?.isReady = true
    }

    func showLoginFlow() {
        links?.isReady = false
        router.switch(to: .login)
    }
}
```

### 2. Tabs, one stack each

The functions have the same names as in the SwiftUI example, so a flow reads the same in both renderers.

```swift
extension AppCoordinator {
    func makeMainTabsFlow() -> UIViewController {
        WaypointTabBarController(router: tabs) { [unowned self] tab in
            self.makeTabFlow(for: tab)
        }
    }

    func makeTabFlow(for tab: MainTab) -> UIViewController {
        switch tab {
        case .home:
            makeHomeFlow()
        case .shop:
            makeShopFlow()
        case .profile:
            makeProfileFlow()
        }
    }

    func makeHomeFlow() -> UIViewController {
        WaypointNavigationController(router: tabs.router(for: .home), root: HomeViewController())
    }

    func makeShopFlow() -> UIViewController {
        WaypointNavigationController(shop)
    }

    func makeProfileFlow() -> UIViewController {
        WaypointNavigationController(router: tabs.router(for: .profile), root: ProfileViewController())
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

    init(router: StackRouter) {
        self.router = router
    }

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
            if case .finished(let filter) = result {
                self?.apply(filter)
            }
        }
    }
}
```

### 5. A deep link

The scene delegate from the first example already forwards URLs and user activities to the app coordinator, and `makeWindow(for:options:)` hands it the links a cold launch brings. The inbox holds them until `showMainFlow()` sets `links?.isReady = true`. Nothing else is needed in the scene delegate.

The matcher, the plans and the link policy are the ones from the SwiftUI example. They live in `WaypointCore`, so both renderers use the same code.
