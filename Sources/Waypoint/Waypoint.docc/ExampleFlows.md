# Five example flows

Login, tabs, a detail push, a sheet and a deep link, in one small SwiftUI app.

## Overview

These five flows cover what most apps need. They build on each other: the app starts at login, switches to tabs, pushes a product, opens a filter sheet and answers a link.

### 1. Login, then the main tabs

The app coordinator owns the app's navigation: the root router, the tabs, the shop flow and the link inbox. The `App` only creates it. The login screen reports that the user logged in, and the coordinator switches the whole screen and releases the login flow.

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
    let links: LinkInbox?
    let tabs: TabRouter<MainTab>
    let shop: ShopCoordinator

    init() {
        let hosts: Set<String> = ["example.com"]
        let schemes: Set<String> = ["myshop"]
        let tabs = TabRouter(selection: MainTab.home)
        self.links = LinkInbox(domains: LinkDomains(hosts: hosts, schemes: schemes))
        self.tabs = tabs
        self.shop = ShopCoordinator(router: tabs.router(for: .shop))
    }

    func makeFlow(for root: AppRoot) -> some View {
        switch root {
        case .login:
            makeLoginFlow()
        case .main:
            makeMainTabsFlow()
        }
    }

    func makeLoginFlow() -> some View {
        LoginView(onLoggedIn: { self.showMainFlow() })
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
```

`LoginView` doesn't import Waypoint. It calls `onLoggedIn`, and the rule for what happens next lives in one place you can test.

Two naming rules keep a coordinator readable. Each `case` body is one call to a named function. Functions that build a flow are named `make…Flow()`, and functions that navigate are named `show…()`, so a reader can tell building from moving at a glance.

### 2. Tabs, one stack each

The app coordinator draws the tabs too. The shop coordinator is created once and kept, so the shop tab keeps its state while the screen redraws.

```swift
extension AppCoordinator {
    func makeMainTabsFlow() -> some View {
        WaypointTabs(tabs, content: makeTabFlow(for:))
    }

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
        WaypointStack(tabs.router(for: .home)) {
            HomeView()
        }
        .tabItem { Label("Home", systemImage: "house") }
    }

    func makeShopFlow() -> some View {
        WaypointStack(shop)
            .tabItem { Label("Shop", systemImage: "bag") }
    }

    func makeProfileFlow() -> some View {
        WaypointStack(tabs.router(for: .profile)) {
            ProfileView()
        }
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
// - `SwiftUIStackCoordinator`, so `WaypointStack` can draw it.
// - `NavigationFlow`, so routes can name it as their flow.
final class ShopCoordinator: SwiftUIStackCoordinator, NavigationFlow {
    let router: StackRouter

    var root: some View {
        ProductListView(
            onSelect: { self.showProduct(id: $0) },
            onFilter: { self.showFilters() }
        )
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { route, navigation in
            ProductView(model: ProductModel(id: route.id, navigation: navigation))
        }
        Destination(CartRoute.self) { _ in CartView() }
    }

    init(router: StackRouter) {
        self.router = router
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
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

    var root: some View {
        FilterView(onApply: { self.finish(with: $0) })
    }
    var destinations: some Destinations { }
}

extension ShopCoordinator {
    func showFilters() {
        let detents: [SheetDetent] = [.medium, .large]
        Task {
            let result = await router.present(FilterCoordinator(), style: .sheet(detents: detents))
            if case .finished(let filter) = result {
                apply(filter)
            }
        }
    }
}
```

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

`WaypointRoot(app)` sends every link to the app coordinator's inbox. If the link arrives during login, it waits. When the app coordinator's `showMainFlow()` switches to the main flow and calls `links?.markReady()`, the link is applied in one step: the sheet closes, the shop tab is selected and the product is pushed, with one animation.
