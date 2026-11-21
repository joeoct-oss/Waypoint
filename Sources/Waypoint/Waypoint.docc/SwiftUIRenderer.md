# The SwiftUI renderer

Draw stacks, sheets, tabs and roots with SwiftUI.

## Overview

> Note: Stacks are built (#11): `WaypointStack`, `destination(_:_:)`, swipe-back sync and the Waypoint link (#147), the missing-destination screen (#166), hiding the tab bar on pushed screens (#207) and the journey line for each screen the user sees (#216). So are the flow initializer, the navigator destination and previews (#25). The rest of this article is planned, not built, and can still change: coordinators (#59), sheets and full-screen covers (#12), tabs (#13), roots (#37, #148) and incoming links (#15).

The SwiftUI renderers draw a coordinator's router with SwiftUI's own containers: `NavigationStack`, sheets, `TabView`. They are the default for every kind of coordinator, and the UIKit ones can replace them: see <doc:Renderers>. The views in this article are also usable on their own. Each takes a router, or makes one for you, and draws its state. Screens are registered by route type. SwiftUI applies one `navigationDestination(for:)` per registered type, so screens are never wrapped in `AnyView`.

The renderer keeps no navigation state of its own. It mirrors the router's path into a `NavigationPath` and reports user pops back to the router. Sheet dismissals, sheet size changes and tab taps are reported the same way once sheets (#12) and tabs (#13) are built.

### Stacks

```swift
/// A navigation stack driven by a `StackRouter`.
///
/// Conformances:
/// - `Root: View`: the stack's first screen.
public struct WaypointStack<Root: View>: View {
    /// Creates a stack with its own router. `rootName` names the first screen
    /// in the journey box, such as "Product list".
    public init(rootName: String? = nil, @ViewBuilder root: () -> Root)

    /// Creates a stack for a router you own.
    public init(_ router: StackRouter, rootName: String? = nil, @ViewBuilder root: () -> Root)

    /// Creates a stack that belongs to a flow, so `@FlowNavigation(Flow.self)`
    /// finds it. The flow is declared on the router with `declareFlow(_:)`.
    public init<Flow: NavigationFlow>(
        flow: Flow.Type,
        router: StackRouter? = nil,
        rootName: String? = nil,
        @ViewBuilder root: () -> Root
    )
}

extension View {
    /// Shows `route`'s screen when a route of type `R` is pushed or presented.
    public func destination<R: Route, Content: View>(
        _ type: R.Type,
        @ViewBuilder _ content: @escaping (R) -> Content
    ) -> some View

    /// The same, and also hands the screen the stack's navigator for its
    /// view model.
    public func destination<R: Route, Content: View>(
        _ type: R.Type,
        @ViewBuilder _ content: @escaping (R, StackNavigator) -> Content
    ) -> some View

    /// The same, and declares how `router.show(_:)` shows the route, such as
    /// `.sheet`. Draft until #12.
    public func destination<R: Route, Content: View>(
        _ type: R.Type,
        presentation: PresentationStyle,
        @ViewBuilder _ content: @escaping (R) -> Content
    ) -> some View
}
```

```swift
let router = StackRouter()

WaypointStack(router) {
    ProductListView(onSelect: { router.push(ProductRoute(id: $0)) })
        .destination(ProductRoute.self) { route in
            ProductView(id: route.id)
        }
}
```

`destination(_:_:)` also registers the route type with the stack's router. Put it on the stack's first screen, or on any screen inside the stack.

**Navigation inside the stack.** Every screen in the stack can read its navigator with `@StackNavigation`, dismiss its flow with `@DismissFlow`, or read the router with `@Environment(StackRouter.self)`. A stack made with `WaypointStack(flow: ShopFlow.self)` is also found by `@FlowNavigation(ShopFlow.self)`. See <doc:NavigatingFromViewsAndViewModels>.

**What the user does comes back.** A swipe back, the Back button and its long-press menu reach the router as one pop each, logged with `origin=user`. The router's path is always what the screen shows.

**Changes during a transition.** A multi-step push or pop runs as one animation. On iOS 17, SwiftUI drops a path change that lands while a push or pop still animates, so there the stack holds the change and shows the router's newest path when the transition ends (about 0.6 s). The transition counts from when the new screens finish drawing, not from the path change, because on a busy device drawing can block the main thread for seconds before iOS 17 starts the push. A change that replaces screens, such as a link from one product to another, is shown there as a pop back to the screens both paths share, then a push. Later systems apply every change at once.

**One push per tap.** The stack tells its router when it starts showing a push and when that push ends (about 0.6 s later), on every system. Until then, a second push of the same route, such as the second tap of a fast double tap on a row, is skipped and returns `.alreadyThere`. See "One push per tap" in the core's stack navigation article to turn it off.

A route with no destination never crashes. The registry is strict, so the router refuses a route type that no `destination(_:_:)` registered, with `unregisteredRoute` and the fallback you choose. Destinations register as the stack is first drawn, before any screen can push.

**A route with no destination in its own stack.** The router can know a type that this stack still can't draw: another stack of the tree registered it, or the root's `NavigationConfiguration` lists it in its registry for restoring. The push goes ahead, and when it ends (about 0.6 s later, or once a restored stack appears) the stack checks that a screen inside it registered each route it shows. A type with none is reported once as `missingDestination` at `.fault` in the `issues` category, in every build, with the fix in its message, and the stack draws its missing-destination screen in place of SwiftUI's empty one. The router's path is kept, and the system Back button still goes back.

- Debug builds show a screen titled "No destination for ProductRoute" that says why the push went ahead and shows the line that fixes it. It names the route's type, never its field values.
- Release builds show a blank screen, so nothing about the app's code reaches its users.

Choose your own screen, for every build, with `missingDestination(_:)` on the stack or any view above it:

```swift
extension View {
    /// Chooses what the stacks inside this view show for a route with no
    /// destination of their own.
    public func missingDestination<Content: View>(
        @ViewBuilder _ content: @escaping (MissingDestination) -> Content
    ) -> some View
}

/// A route a stack shows, but no screen inside that stack registered a
/// destination for.
public struct MissingDestination {
    public let route: AnyRoute
    public let issue: NavigationIssue
    /// The name of the route's type, such as `ProductRoute`.
    public var routeTypeName: String { get }
}
```

```swift
WaypointStack(router) {
    ShopView()
}
.missingDestination { missing in
    UnavailableView(onBack: { router.pop() })
}
```

**The tab bar on pushed screens.** A stack leaves the tab bar as the system shows it, so it stays on pushed screens, as Apple's guidelines suggest. To hide it on every screen pushed above a tab's root, as `hidesBottomBarWhenPushed` does in UIKit, choose it once on the stack, or on any view above the stacks it should change:

```swift
extension View {
    /// Chooses whether the tab bar shows on the screens pushed onto the
    /// stacks inside this view. A stack's first screen is never changed.
    /// Default: `.automatic`, the system's. `motion` says how a hidden bar
    /// leaves and comes back. Default: `.slidesWithScreen`.
    public func tabBarOnPushedScreens(
        _ visibility: Visibility,
        motion: PushedTabBarMotion = .slidesWithScreen
    ) -> some View
}
```

```swift
WaypointStack(router) {
    ProductListView()
        .destination(ProductRoute.self) { route in
            ProductView(id: route.id)
        }
}
.tabBarOnPushedScreens(.hidden)
```

The stack applies it around each pushed screen, the missing-destination screen included, and sends nothing for `.automatic`. Screens don't decide it themselves, so a new screen gets it right without doing anything, and a screen in a sheet or a full-screen cover never touches the tab bar. SwiftUI lets the stack's value win over one a screen sets inside itself, so every pushed screen of the stack gets the same visibility. With `.hidden`, the bar leaves with the stack's first screen as UIKit's `hidesBottomBarWhenPushed` does: the pushed screen slides in on top of it, and a pop, a swipe back (also one that is cancelled) and a pop to the first screen bring it back the same way. SwiftUI's own hide still decides whether the bar shows; the stack only puts a picture of the bar in its first screen while a push from it or a pop to it runs, and does nothing when it can't find the bar. The picture of the bar that comes back on a pop is the one taken at the push, so a change to the bar meanwhile, such as a new badge, shows once the pop ends. Pass `motion: .system` for SwiftUI's own motion, where the bar disappears at the start of a push and appears once a pop ends. The tab bar only exists on iOS, so other systems ignore it.

> Note: Apps show a coordinator's `view` and never create or wire a stack themselves. Waypoint makes one wherever a coordinator starts a new stack: the app's root, a presented flow, a tab's root, or a flow shown from existing app code (#151). A pushed child coordinator shares its parent's stack. A destination may return a SwiftUI view or a UIKit view controller, in either renderer. Apps still push routes, never views. See <doc:Renderers>.

### The Waypoint link

Use `WaypointLink` where you would write `NavigationLink(value:)`. A tap calls `push` on the router of the nearest stack, so the push is checked, logged and saved like any other: a route type with no destination is refused, a second tap while the screen still slides in pushes nothing, and a failed push runs its fallback.

```swift
/// A view that pushes a route onto the nearest Waypoint stack when tapped.
///
/// Conformances:
/// - `Label: View`: what the link shows.
/// - `R: Route`: the route type the link pushes.
public struct WaypointLink<Label: View, R: Route>: View {
    public init(
        value: R?,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        @ViewBuilder label: () -> Label
    )
}

extension WaypointLink where Label == Text {
    public init(
        _ titleKey: LocalizedStringKey,
        value: R?,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    )

    public init<S: StringProtocol>(
        _ title: S,
        value: R?,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    )
}
```

**Moving a view is a rename.** The initializers take the same arguments as the system link's, so existing SwiftUI code moves onto Waypoint by renaming `NavigationLink` to `WaypointLink`:

```swift
// Before
NavigationLink(value: ProductRoute(id: product.id)) {
    ProductRow(product: product)
}
NavigationLink("Orders", value: OrdersRoute())

// After
WaypointLink(value: ProductRoute(id: product.id)) {
    ProductRow(product: product)
}
WaypointLink("Orders", value: OrdersRoute())
```

Pass `else:` to choose the fallback of one link, such as `WaypointLink(value: route, else: .popToRoot) { … }`. The log and any issue name the line that made the link.

The link is disabled when its value is `nil`, like a system link, and outside a Waypoint stack, where there is no router to push onto. It draws as a `Button`, so `.buttonStyle(_:)` styles it. Unlike a system link, it shows no disclosure chevron in a `List`; add one to the label if the row needs it.

> Important: Don't use `NavigationLink(value:)` inside a Waypoint stack. SwiftUI hands the stack a new path entry that can't be read back as a route, so the stack refuses the push, draws the router's path again and reports `rendererMismatch` at `.error` in the `issues` category. Nothing in the report depends on `DEBUG`, so release builds log it too, to the log handler in the root's `NavigationConfiguration`. The message names `WaypointLink` as the fix. `NavigationLink(destination:)` for a screen outside Waypoint's routes still works.

### Coordinators

> Note: Draft until #59. One coordinator protocol for each kind, written once for SwiftUI and UIKit, is designed in <doc:Renderers> and built in #59.

A coordinator gives a flow its root screen and its destinations in one place. Its `view` is the whole flow, drawn by its renderer. With the SwiftUI renderer, that is a `SwiftUIStackRenderer`, which draws with `WaypointStack` and registers every destination before the first push:

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
final class ShopCoordinator: StackCoordinator {
    var root: some Screen {
        ProductListView(onSelect: { self.showProduct(id: $0) })
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { route in
            ProductView(id: route.id, onBuy: { self.showCart() })
        }
        Destination(CartRoute.self) { _ in
            CartView()
        }
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }

    func showCart() {
        router.push(CartRoute())
    }
}
```

`ShopCoordinator().view` is the whole flow, drawn. The router comes from the conformance, so the coordinator doesn't declare one. A coordinator that declares `let router = StackRouter()` uses its own, as tests and previews do.

`WaypointStack(router) { … }` and `WaypointStack(flow:router:root:)` above stay as the lower-level views, for a stack that no coordinator runs.

### Sheets and full-screen covers

> Note: Draft until #12.

Presentations are drawn from router state. A presented route uses the destination registered for its type, and a presented coordinator is drawn by its own renderer inside the sheet or cover this renderer makes. A destination can declare how its route is shown, so `router.show(_:)` presents it without repeating the style: see "Declared presentation" in the core's presentation article. Sheet sizes come from the presentation's `SheetOptions` and map to `PresentationDetent`:

| `SheetDetent` | SwiftUI |
|---|---|
| `.medium`, `.large` | `.medium`, `.large` |
| `.fraction(f)` | `.fraction(f)` |
| `.height(h)` | `.height(h)` |
| `.fitsContent` | `.height(measured)`, capped at `fitsContentLimit`; the content is measured with `onGeometryChange` and placed in a `ScrollView` that only scrolls when it overflows |
| `.custom(name)` | the rule registered for `name` |

```swift
extension View {
    /// Defines an app-specific sheet size, used by `SheetDetent.custom(name)`.
    public func sheetDetent(_ name: String, _ detent: PresentationDetent) -> some View
}

WaypointStack { HomeView() }
    .sheetDetent("compact", .height(220))
```

### Tabs

> Note: Draft until #13.

A tab coordinator owns a `TabRouter` and one stack coordinator for each tab. Its `view` is drawn by `SwiftUITabRenderer`, a `TabView`, and each tab shows its stack coordinator's `view`:

```swift
// Conformances:
// - `TabCoordinator`, so Waypoint can draw its tabs.
final class MainTabsCoordinator: TabCoordinator {
    let router = TabRouter(selection: MainTab.home)
    let home = HomeCoordinator()
    let shop = ShopCoordinator()

    @ViewBuilder
    func makeTabFlow(for tab: MainTab) -> some View {
        switch tab {
        case .home:
            makeHomeFlow()
        case .shop:
            makeShopFlow()
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
}
```

No router is passed by hand: each tab's stack coordinator joins the tab router as soon as the tab coordinator joins the tree, before any call or link reaches it, so `router(for:)` returns that same router from the start. A router read earlier, such as in a test, works on its own and keeps its screens when it joins. Waypoint has to know which stack coordinator belongs to which tab before the tabs are drawn. How the tab coordinator tells it, a requirement that maps each tab to its coordinator or a rule over `makeTabFlow(for:)`, is designed in #59. `makeTabFlow(for:)` has a `switch` over your tab enum, one `make…Flow()` call per case. That is fine here: it lists the tabs once, in one place, not every screen. Apps draw their own tab labels. See <doc:ExampleFlows>.

The lower-level view draws a `TabRouter` with a closure, for tabs that no coordinator runs:

```swift
/// A tab view driven by a `TabRouter`. Each tab gets its own stack.
///
/// Conformances:
/// - `Tab: NavigationTab`, the app's tab type.
/// - `Content: View`: what SwiftUI shows.
public struct WaypointTabs<Tab: NavigationTab, Content: View>: View {
    public init(_ router: TabRouter<Tab>, @ViewBuilder content: @escaping (Tab) -> Content)
}
```

### Roots

> Note: Draft until #37 and #148.

An app coordinator returns the coordinator of each root's flow from `makeFlow(for:)`, and Waypoint draws that coordinator's `view`. `WaypointRoot` makes the app coordinator and draws its `view`, and the `App` holds nothing else:

```swift
extension WaypointRoot {
    /// Creates the app coordinator once for this window and draws its `view`.
    ///
    /// Each window gets its own coordinator, so two windows on iPad never
    /// share a stack, a link inbox or saved state. If the coordinator has a
    /// link inbox, URL opens, universal links and user activities go to it,
    /// and its root router is attached.
    public init<C: RootCoordinator>(
        _ makeCoordinator: @escaping @MainActor () -> C
    ) where Root == C.Root, Content == C.Renderer
}
```

App-wide things, such as the signed-in session and the app's services, stay in the `App` and are passed to the coordinator when it is created. Only the navigation is per window. The per-window initializer is built in #148.

```swift
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
```

<doc:ExampleFlows> shows the whole `AppCoordinator`. The lower-level form draws a `RootRouter` with a closure:

```swift
/// Draws whichever root a `RootRouter` is showing.
///
/// Conformances:
/// - `Root: NavigationRoot`, the app's root type.
/// - `Content: View`: what SwiftUI shows.
public struct WaypointRoot<Root: NavigationRoot, Content: View>: View {
    public init(_ router: RootRouter<Root>, @ViewBuilder content: @escaping (Root) -> Content)
}
```

### Incoming links

`WaypointRoot { AppCoordinator() }` wires the app coordinator's inbox, so most apps never call this. It is for apps that draw a `RootRouter` directly:

```swift
extension View {
    /// Sends URL opens, universal links and user activities to the inbox,
    /// and attaches the nearest root router.
    public func incomingLinks(_ inbox: LinkInbox) -> some View
}
```

### Previews

Views that read navigation from the environment need a router above them. In previews, add one:

```swift
#Preview {
    ProductView(id: 1)
        .waypointPreview(flow: ShopFlow.self)
}

extension View {
    /// Wraps the view in a stack with a fresh router whose registry is permissive, so
    /// environment navigation works and pushes need no registered destination.
    public func waypointPreview() -> some View

    /// The same, with the stack declared for `flow`, so `@FlowNavigation(flow)`
    /// finds it.
    public func waypointPreview<Flow: NavigationFlow>(flow: Flow.Type) -> some View
}
```
