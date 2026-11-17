# Five example flows

Login, tabs, a detail push, a sheet and a deep link, in one small SwiftUI app.

## Overview

These five flows cover what most apps need. They build on each other: the app starts at login, switches to tabs, pushes a product, opens a filter sheet and answers a link.

### 1. Login, then the main tabs

The app coordinator owns the app's navigation: the root router, the tabs, the shop flow and the link inbox. The `App` only creates it. The login screen reports that the user logged in, and the coordinator switches the whole screen and releases the login flow.

```swift
// Conformances:
// - `Hashable`, required by `RootRouter`, which compares roots to know when to switch.
// - `Codable`, required by `RootRouter`, which saves and restores the current root with the tree.
// - `Sendable`, required by `RootRouter`, so events that name the root can leave the main actor.
enum AppRoot: Hashable, Codable, Sendable {
    case login
    case main
}
// Conformances:
// - `String` raw value: gives each case a readable name in logs and saved state.
// - `Hashable`, required by `TabRouter`, which selects and compares tabs.
// - `Codable`, required by `TabRouter`, which saves and restores the selection with the tree.
// - `Sendable`, required by `TabRouter`, so events that name the tab can leave the main actor.
enum MainTab: String, Hashable, Codable, Sendable {
    case home
    case shop
    case profile
}

@main
struct ShopApp: App {
    @State private var app = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            WaypointRoot(app)
        }
    }
}

// Conformances:
// - `SwiftUIRootCoordinator`, so `WaypointRoot` can draw it.
final class AppCoordinator: SwiftUIRootCoordinator {
    let router = RootRouter(AppRoot.login)
    let links: LinkInbox? = LinkInbox(domains: LinkDomains(hosts: ["example.com"], schemes: ["myshop"]))
    let tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)
    private(set) lazy var shop = ShopCoordinator(router: tabs.router(for: .shop))

    func content(for root: AppRoot) -> some View {
        switch root {
        case .login:
            LoginView(onLoggedIn: { self.didLogIn() })
        case .main:
            mainTabs
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

`LoginView` doesn't import Waypoint. It calls `onLoggedIn`, and the rule for what happens next lives in one place you can test.

### 2. Tabs, one stack each

The app coordinator draws the tabs too. The shop coordinator is created once and kept, so the shop tab keeps its state while the screen redraws.

```swift
extension AppCoordinator {
    var mainTabs: some View {
        WaypointTabs(tabs) { tab in
            switch tab {
            case .home:
                WaypointStack(self.tabs.router(for: .home)) {
                    HomeView()
                }
                .tabItem { Label("Home", systemImage: "house") }
            case .shop:
                WaypointStack(self.shop)
                    .tabItem { Label("Shop", systemImage: "bag") }
            case .profile:
                WaypointStack(self.tabs.router(for: .profile)) {
                    ProfileView()
                }
                .tabItem { Label("Profile", systemImage: "person") }
            }
        }
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
    let id: Int
    static let pattern: URLPattern = "/product/:id"
    init(id: Int) { self.id = id }
    init(link: DeepLinkParameters) throws { id = try link.int("id") }
}

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct CartRoute: Route {
    typealias Flow = ShopCoordinator
}

// Conformances:
// - `SwiftUIStackCoordinator`, so `WaypointStack` can draw it.
// - `NavigationFlow`, so routes can name it as their flow.
final class ShopCoordinator: SwiftUIStackCoordinator, NavigationFlow {
    let router: StackRouter
    init(router: StackRouter) { self.router = router }

    var root: some View {
        ProductListView(onSelect: { self.router.push(ProductRoute(id: $0)) },
                        onFilter: { self.showFilters() })
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { route, navigation in
            ProductView(model: ProductModel(id: route.id, navigation: navigation))
        }
        Destination(CartRoute.self) { _ in CartView() }
    }
}
```

### 4. A sheet that returns a result

The filter flow ends with a value. The user can also swipe it away, which gives `.cancelled`. Either way, the result arrives exactly once.

```swift
// Conformances:
// - `SwiftUIStackCoordinator`, so `WaypointStack` can draw it.
// - `FlowFinishing`, so it can hand a result back to whoever started it.
final class FilterCoordinator: SwiftUIStackCoordinator, FlowFinishing {
    typealias Output = ProductFilter
    let router = StackRouter()

    var root: some View { FilterView(onApply: { self.finish(with: $0) }) }
    var destinations: some Destinations { }
}

extension ShopCoordinator {
    func showFilters() {
        Task {
            let result = await router.present(FilterCoordinator(), style: .sheet(detents: [.medium, .large]))
            if case .finished(let filter) = result { apply(filter) }
        }
    }
}
```

Inside the filter screen, a view can end the flow without a closure:

```swift
struct FilterView: View {
    @FinishFlow(FilterCoordinator.self) private var finish
    var body: some View { Button("Apply") { finish(ProductFilter.default) } }
}
```

### 5. A deep link

`myshop://product/42` and `https://example.com/product/42` both open the product. Because the route declares its pattern, registering its destination is enough. A link that needs several steps uses a plan:

```swift
matcher.register("/sale/:id") { link in
    NavigationPlan {
        DismissAll()
        SelectTab(MainTab.shop)
        SetPath(in: MainTab.shop) {
            ProductRoute(id: try link.int("id"))
        }
    }
}
```

`WaypointRoot(app)` sends every link to the app coordinator's inbox. If the link arrives during login, it waits. When the app coordinator's `didLogIn()` switches to the main flow and sets `links?.isReady = true`, the link is applied in one step: the sheet closes, the shop tab is selected and the product is pushed, with one animation.
