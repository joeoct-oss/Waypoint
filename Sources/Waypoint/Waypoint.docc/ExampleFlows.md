# Five example flows

Login, tabs, a detail push, a sheet and a deep link, in one small SwiftUI app.

## Overview

> Note: Draft until #59. The API in this article is planned, not built, and can still change: coordinators (#59), flow results (#60), sheets and `show` (#12), tabs (#13), roots (#37) and links (#15).

These five flows cover what most apps need. They build on each other: the app starts at login, switches to tabs, pushes a product, opens a filter sheet and answers a link. The coordinators here are the same ones a UIKit app uses: see <doc:ExampleFlowsInUIKit>.

### 1. Login, then the main tabs

The app coordinator owns the app's navigation: the root router and the link inbox. The `App` only creates it. The login screen reports that the user logged in, and the coordinator switches the whole screen and releases the login flow.

```swift
// Conformances:
// - `NavigationRoot`, so `RootRouter` can compare roots to know when to switch, save and restore
//   the current root, and name it in events off the main actor.
enum AppRoot: NavigationRoot {
    case login
    case main
}

// Conformances:
// - `String` raw value: gives each case a readable name in logs and saved state.
// - `NavigationTab`, so `TabRouter` can select and compare tabs, save and restore the selection,
//   and name tabs in events off the main actor.
// - `CaseIterable`, so `TabRouter` shows every tab without a list.
enum MainTab: String, NavigationTab, CaseIterable {
    case home
    case shop
    case profile
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

// Conformances:
// - `RootCoordinator`, so `WaypointRoot` can draw it and send it incoming links.
final class AppCoordinator: RootCoordinator {
    let router = RootRouter(AppRoot.login)
    let links: LinkInbox?

    init() {
        let hosts: Set<String> = ["example.com"]
        let schemes: Set<String> = ["myshop"]
        self.links = LinkInbox(domains: LinkDomains(hosts: hosts, schemes: schemes))
    }

    func makeFlow(for root: AppRoot) -> some RootFlow {
        switch root {
        case .login:
            makeLoginFlow()
        case .main:
            makeMainTabsFlow()
        }
    }

    func makeLoginFlow() -> LoginCoordinator {
        LoginCoordinator(onLoggedIn: { self.showMainFlow() })
    }

    func makeMainTabsFlow() -> MainTabsCoordinator {
        MainTabsCoordinator()
    }

    func showMainFlow() {
        router.switch(to: .main)
        links?.markReady()
    }

    func showLoginFlow() {
        links?.markNotReady()
        router.switch(to: .login)
    }
}

// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
final class LoginCoordinator: StackCoordinator {
    let onLoggedIn: () -> Void

    var root: some Screen {
        LoginView(onLoggedIn: onLoggedIn)
    }

    var destinations: some Destinations { }

    init(onLoggedIn: @escaping () -> Void) {
        self.onLoggedIn = onLoggedIn
    }
}
```

`makeFlow(for:)` returns the coordinator of each root's flow, and Waypoint draws its `view`. It runs once each time the root switches, so each flow is made fresh and released when the root switches away. The app coordinator keeps the router and the inbox, which live as long as the window.

`LoginView` doesn't import Waypoint. It calls `onLoggedIn`, and the rule for what happens next lives in one place you can test.

Two naming rules keep a coordinator readable. Each `case` body is one call to a named function. Functions that build a flow are named `make…Flow()`, and functions that navigate are named `show…()`, so a reader can tell building from moving at a glance.

### 2. Tabs, one stack each

The tab coordinator owns the tab router and one stack coordinator for each tab. Each is created once and kept, so a tab keeps its state while the screen redraws. The tab coordinator hands each one its tab's stack router.

```swift
// Conformances:
// - `TabCoordinator`, so Waypoint can draw its tabs and make its router.
final class MainTabsCoordinator: TabCoordinator {
    let home = HomeCoordinator()
    let shop = ShopCoordinator()
    let profile = ProfileCoordinator()

    @ViewBuilder
    func makeTabFlow(for tab: MainTab) -> some View {
        switch tab {
        case .home:
            makeHomeFlow()
        case .shop:
            makeShopFlow()
        case .profile:
            makeProfileFlow()
        }
    }

    func makeHomeFlow() -> some View {
        home.view
            .tabItem { Label("Home", systemImage: "house") }
    }

    func makeShopFlow() -> some View {
        shop.view
            .tabItem { Label("Shop", systemImage: "bag") }
    }

    func makeProfileFlow() -> some View {
        profile.view
            .tabItem { Label("Profile", systemImage: "person") }
    }
}
```

### 3. A detail push

One route type per screen, one registration line each. The product route can also be opened from a link.

```swift
// Conformances:
// - `Route`, so it can be pushed, presented and saved.
// - `DeepLinkable`, so it can be opened from a URL.
struct ProductRoute: Route, DeepLinkable {
    typealias Flow = ShopCoordinator

    static let pattern: URLPattern = "/product/:id"

    let id: Int

    init(id: Int) {
        self.id = id
    }

    init(link: DeepLinkParameters) throws {
        id = try link.int("id")
    }
}

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct CartRoute: Route {
    typealias Flow = ShopCoordinator
}

// Conformances:
// - `Route`, so it can be shown and saved.
struct FilterRoute: Route {
    typealias Flow = ShopCoordinator
}

// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
// - `NavigationFlow`, so routes can name it as their flow.
final class ShopCoordinator: StackCoordinator, NavigationFlow {
    private static let filterDetents: [SheetDetent] = [.medium, .large]

    var root: some Screen {
        ProductListView(
            onSelect: { self.showProduct(id: $0) },
            onFilter: { self.showFilters() }
        )
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { route, navigation in
            ProductView(model: ProductModel(id: route.id, navigation: navigation))
        }
        Destination(CartRoute.self) { _ in
            CartView()
        }
        Flow(FilterRoute.self, presentation: .sheet(detents: Self.filterDetents)) { _ in
            FilterCoordinator()
        } onResult: { result in
            self.filterEnded(result)
        }
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }
}
```

The shop coordinator declares no router: the tab coordinator gives it the shop tab's stack router.

### 4. A sheet that returns a result

The filter flow ends with a value. The user can also swipe it away, which gives `.cancelled`. Either way, the result arrives exactly once, at the `onResult:` handler of the `Flow(...)` entry above, also after the app is relaunched with the sheet restored.

```swift
// Conformances:
// - `FlowCoordinator`, so it can be presented and hand a result back to whoever started it.
final class FilterCoordinator: FlowCoordinator {
    typealias Output = ProductFilter

    var root: some Screen {
        FilterView(onApply: { self.finish(with: $0) })
    }

    var destinations: some Destinations { }
}

extension ShopCoordinator {
    func showFilters() {
        router.show(FilterRoute())
    }

    func filterEnded(_ result: FlowResult<ProductFilter>) {
        switch result {
        case .finished(let filter):
            apply(filter)
        case .cancelled:
            break
        }
    }
}
```

`router.show(FilterRoute())` presents the filter as its entry declares: a sheet at medium or large. `router.present(FilterRoute(), style: .fullScreenCover)` would still choose for one call. A flow that is only started in one place can also be awaited: `await router.present(FilterCoordinator(), style: .sheet)` returns the same `FlowResult`.

Inside the filter screen, a view can end the flow without a closure:

```swift
struct FilterView: View {
    @FinishFlow(FilterCoordinator.self) private var finish

    var body: some View {
        Button("Apply") { finish(ProductFilter.default) }
    }
}
```

### 5. A deep link

`myshop://product/42` and `https://example.com/product/42` both open the product. Because the route declares its pattern, registering its destination is enough. A link that needs several steps uses a plan:

```swift
let matcher = DeepLinkMatcher()
    .registering("/sale/:id") { link in
        NavigationPlan {
            DismissAll()
            SelectTab(MainTab.shop)
            SetPath(in: MainTab.shop) {
                ProductRoute(id: try link.int("id"))
            }
        }
    }
```

`WaypointRoot` sends every link to the app coordinator's inbox. If the link arrives during login, it waits. When the app coordinator's `showMainFlow()` switches to the main flow and calls `links?.markReady()`, the link is applied in one step: the sheet closes, the shop tab is selected and the product is pushed, with one animation.

This example holds every link until sign-in by marking the inbox ready in `showMainFlow()`. Per-link requirements, where the app coordinator holds only the links that need sign-in and saves them across relaunches, are coming in #150; see the Deep links article in WaypointCore.
