# Five example flows

Login, tabs, a detail push, a sheet and a deep link, in one small SwiftUI app.

## Overview

These five flows cover what most apps need. They build on each other: the app starts at login, switches to tabs, pushes a product, opens a filter sheet and answers a link.

### 1. Login, then the main tabs

The root router holds which flow is showing. Logging in switches the whole screen and releases the login flow.

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
    @State private var root = RootRouter(AppRoot.login)
    @State private var tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)
    @State private var inbox = LinkInbox(domains: LinkDomains(hosts: ["example.com"], schemes: ["myshop"]))

    var body: some Scene {
        WindowGroup {
            WaypointRoot(root) { current in
                switch current {
                case .login:
                    LoginView(onLoggedIn: { root.switch(to: .main) })
                case .main:
                    MainTabsView(tabs: tabs)
                }
            }
            .incomingLinks(inbox)
        }
    }
}
```

### 2. Tabs, one stack each

```swift
struct MainTabsView: View {
    let tabs: TabRouter<MainTab>

    var body: some View {
        WaypointTabs(tabs) { tab in
            switch tab {
            case .home:
                WaypointStack(tabs.router(for: .home)) {
                    HomeView()
                }
                .tabItem { Label("Home", systemImage: "house") }
            case .shop:
                WaypointStack(ShopCoordinator(router: tabs.router(for: .shop)))
                    .tabItem { Label("Shop", systemImage: "bag") }
            case .profile:
                WaypointStack(tabs.router(for: .profile)) {
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

If the link arrives during login, it waits. After `root.switch(to: .main)` and once the app sets `inbox.isReady = true`, it is applied in one step: the sheet closes, the shop tab is selected and the product is pushed, with one animation.
