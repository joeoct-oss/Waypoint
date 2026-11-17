# Five example flows

Login, tabs, a detail push, a sheet and a deep link, in one small SwiftUI app.

## Overview

These five flows cover what most apps need. They build on each other: the app starts at login, switches to tabs, pushes a product, opens a filter sheet and answers a link.

### 1. Login, then the main tabs

The root router holds which flow is showing. Logging in switches the whole screen and releases the login flow.

```swift
enum AppRoot: Hashable, Codable, Sendable { case login, main }
enum MainTab: String, Hashable, Codable, Sendable { case home, shop, profile }

@main
struct ShopApp: App {
    @State private var root = RootRouter(AppRoot.login)
    @State private var tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)
    @State private var inbox = LinkInbox(domains: LinkDomains(hosts: ["example.com"], schemes: ["myshop"]))

    var body: some Scene {
        WindowGroup {
            WaypointRoot(root) { current in
                switch current {
                case .login: LoginView(onLoggedIn: { root.switch(to: .main) })
                case .main: MainTabsView(tabs: tabs)
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
            case .home: WaypointStack(tabs.router(for: .home)) { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
            case .shop: WaypointStack(ShopCoordinator(router: tabs.router(for: .shop)))
                .tabItem { Label("Shop", systemImage: "bag") }
            case .profile: WaypointStack(tabs.router(for: .profile)) { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
            }
        }
    }
}
```

### 3. A detail push

One route type per screen, one registration line each. The product route can also be opened from a link.

```swift
struct ProductRoute: Route, DeepLinkable {
    typealias Flow = ShopCoordinator
    let id: Int
    static let pattern: URLPattern = "/product/:id"
    init(id: Int) { self.id = id }
    init(link: DeepLinkParameters) throws { id = try link.int("id") }
}

struct CartRoute: Route { typealias Flow = ShopCoordinator }

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
