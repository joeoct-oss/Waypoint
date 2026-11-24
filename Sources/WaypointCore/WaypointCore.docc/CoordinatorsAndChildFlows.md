# Coordinators and child flows

Group screens into flows, nest them, and get a result back when a flow ends.

## Overview

> Note: Draft until #59. The API in this article is planned, not built, and can still change: coordinators (#59), flow results (#60) and flow routes (#152).

A coordinator is your own object that owns one router, the flow's dependencies and its logic. Screens report what happened through outputs, closures you pass in, and the coordinator decides where to go next. Screens never import Waypoint.

Coordinators are optional. A plain stack with a few `.destination` lines needs none. Add one when a flow has logic or dependencies worth keeping in one place.

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
final class ShopCoordinator: StackCoordinator {
    let catalog: CatalogService

    init(catalog: CatalogService) {
        self.catalog = catalog
    }

    func showProduct(_ id: Int) {
        router.push(ProductRoute(id: id))
    }
}
```

A stack or flow coordinator doesn't declare its router. Waypoint makes it the first time it is read, names it after the coordinator, gives it the coordinator's destinations, and releases it when the coordinator is gone. A coordinator that wants a router of its own, such as one with the app's configuration, as tests and previews do, implements `makeRouter()`. A stored `let router` goes around Waypoint: the first time Waypoint touches the coordinator, such as when it hands out a navigator, it reports `routerNotFromWaypoint` and adopts that router, and a stored router another coordinator owns is reported as `routerOwnedByAnotherCoordinator` and left with its owner.

> Warning: Don't read a coordinator's router in `deinit`. A coordinator going away gets an inert router: its calls return `.ignored` and log `staleNavigator`. A coordinator that subclasses `NSObject` traps there instead.

Built so far in #59: `StackCoordinating` in `WaypointCore` and `StackCoordinator` in `Waypoint`, with the router, `makeRouter()`, `rootName`, `registerDestinations(on:)`, `navigator` and `navigator(for:)`; `TabCoordinating` in `WaypointCore` and `TabCoordinator` in `Waypoint`, with the router, `makeRouter()`, each tab's coordinator and `navigator(for:)`; and `FlowCoordinating` in `WaypointCore` and `FlowCoordinator` in `Waypoint`, with `finish(with:)`, presenting a child flow with `onFinish:` in both forms, and `FlowResult`. The rest of this article is still planned.

There is one coordinator protocol for each kind, and it is the same in SwiftUI and UIKit apps. The `Waypoint` product adds the screens: `root` and `destinations`, which take SwiftUI views or UIKit view controllers, and `view`, the whole flow drawn by a renderer you can choose. See "Coordinators and renderers" in the `Waypoint` catalog. The parts below have no UI, so a coordinator's logic is tested on Linux.

### Coordinator protocols

```swift
/// App code that owns one stack flow.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol StackCoordinating: AnyObject {
    /// The router of this coordinator's stack. Default: made with `makeRouter()` the first
    /// time it is read, and kept until the coordinator is gone.
    var router: StackRouter { get }

    /// The name of the stack's root screen in the journey. Default: the type's name without
    /// `Coordinator`, such as `Shop` for `ShopCoordinator`.
    var rootName: String { get }

    /// Makes the router, the first time `router` is read. Default: `StackRouter()`.
    func makeRouter() -> StackRouter

    /// Registers the route types the screens show, once per router. Default: registers
    /// nothing. `StackCoordinator` in `Waypoint` registers its `destinations`.
    func registerDestinations(on router: StackRouter)
}

/// App code that owns a tab container, with one stack coordinator for each tab.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol TabCoordinating: AnyObject {
    /// The app's tab type, usually an enum.
    associatedtype Tab: NavigationTab

    /// The router of the tab container. Default: made with `makeRouter()` the first time it
    /// is read, with each tab's coordinator asked for then.
    var router: TabRouter<Tab> { get }

    /// Makes the router. No default, because only the app knows its tabs and which one is
    /// selected first, such as `TabRouter(tabs: MainTab.allCases, selection: .home)`.
    func makeRouter() -> TabRouter<Tab>

    /// The stack coordinator of `tab`, asked once per tab. `TabCoordinator` in `Waypoint` fills
    /// it in from its `tabCoordinator(for:)`, which returns `any StackCoordinator`.
    func coordinator(for tab: Tab) -> any StackCoordinating
}

/// App code that owns a child flow, presented or pushed, that ends with a value for whoever
/// started it.
///
/// Conformances:
/// - `StackCoordinating`, because a flow is a stack with a router of its own.
@MainActor
public protocol FlowCoordinating: StackCoordinating {
    /// What the flow hands back, such as a picked address.
    associatedtype Output: Sendable

    /// Ends the flow with `output`. Waypoint delivers the result, dismisses the flow, and
    /// lets the coordinator go. Default: filled in by Waypoint.
    func finish(with output: Output)
}
```

### The app coordinator

An app with more than one root flow, such as login and the main tabs, keeps its navigation in an app coordinator: your own type at the top of the coordinator tree. It owns the root router and the link inbox, which live as long as the window, and makes the flow for each root when the root switches, such as a tab coordinator with its own tab router. It also decides what happens between flows. The `App` or scene delegate only creates it and hands it to the renderer, and screens report what happened instead of switching roots themselves.

```swift
/// App code that owns the app's top-level flow: which root shows, and where links go.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol RootCoordinator: AnyObject {
    /// Conformances:
    /// - `Hashable`, `Codable` and `Sendable`, required by `RootRouter`.
    associatedtype Root: NavigationRoot

    /// The router this coordinator owns. No default, because only the app knows its first
    /// root, such as `let router = RootRouter(AppRoot.login)`.
    var router: RootRouter<Root> { get }

    /// Where incoming links go, or `nil` if the app takes no links.
    ///
    /// There is no default, so every app says which it means.
    var links: LinkInbox? { get }
}
```

The `Waypoint` product adds `makeFlow(for:)`, which returns the coordinator of each root's flow, and the window entries: `WaypointRoot { … }` in a SwiftUI app and `makeWindow(for:options:)` in a UIKit scene delegate. See <doc:RootSwitching> for a whole app coordinator.

### Joining the tree

A child coordinator's router joins its parent's tree before any call or link reaches the parent: a tab's stack coordinator joins the tab router as soon as the tab coordinator joins the tree, so the tab router's `router(for:)` returns that same router from the start, and a presented or pushed child joins when it starts. A router read earlier, such as in a test, works on its own and keeps its screens when it joins. A tab coordinator names each tab's coordinator with `tabCoordinator(for:)`, asked once per tab when its router is first read, and again for a tab `setTabs` adds later; a removed tab's coordinator is let go. Return a different coordinator for each tab, a new one or one the tab coordinator keeps (a kept one returned again for a tab added back gets the tab's new stack): one returned for two tabs is reported as `coordinatorDrawnTwice`, and a child whose router another coordinator owns, or that is already in another tree, is reported as `routerOwnedByAnotherCoordinator` or `routerInAnotherTree`. Each of those tabs keeps a stack of its own, or shows the tabs' shared stack.

```swift
// Conformances:
// - `TabCoordinator`, so Waypoint makes its router and gives each tab its coordinator's stack.
final class MainTabsCoordinator: TabCoordinator {
    func makeRouter() -> TabRouter<MainTab> {
        TabRouter(tabs: MainTab.allCases, selection: .home)
    }

    func tabCoordinator(for tab: MainTab) -> any StackCoordinator {
        switch tab {
        case .home:
            HomeCoordinator()
        case .shop:
            ShopCoordinator()
        }
    }
}
```

With `TabRouter(stacks: .shared)`, the selected tab's coordinator is asked first and its router becomes the shared stack. Every other tab's coordinator drives that same stack: its router's calls go to the shared stack, and screens it pushed before it joined are dropped and reported as `tabChildRouterMerged`. The journey names the shared stack after the selected tab's coordinator.

> Warning: A tab's coordinator that holds its tab coordinator strongly makes a cycle, so neither is freed. Give children what they need through their dependencies.

Create child coordinators once and keep them in their parent coordinator, not inside a view's `body`, so a flow keeps its state while the screen redraws.

A coordinator's closures, such as a screen's output or a `Flow(...)` entry's `onResult:` handler, may capture `self`. Waypoint keeps them with the flow's router and drops them when the flow ends, and for the window's own flows when the window's scene goes away, so no cycle outlives the flow. `[weak self]`, as UIKit code often writes, works too. A leak test for each kind of flow is part of #59.

### A coordinator as its own flow type

A coordinator can be its own `NavigationFlow`. Routes then name it as their flow, and the coordinator gets a scoped handle for free. A separate empty `enum ShopFlow: NavigationFlow { }` works just as well. Neither is required.

```swift
// Conformances:
// - `StackCoordinator`, so Waypoint can draw its stack and make its router.
// - `NavigationFlow`, so routes can name it as their flow.
final class ShopCoordinator: StackCoordinator, NavigationFlow {
    ...
}

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct CartRoute: Route {
    typealias Flow = ShopCoordinator
}

extension StackCoordinator where Self: NavigationFlow {
    /// A handle that only accepts this coordinator's routes.
    public var navigator: FlowNavigator<Self> { get }
}
```

### Starting a child flow

A child flow is a `FlowCoordinator`. Presenting one starts it: the child's router joins the presenting router's tree, with any screens it already pushed, and takes the tree's settings, fallbacks and registered routes from then on. The parent gets the flow's result in `onFinish:` exactly once, after the call that ended the flow is done. Waypoint keeps the child until its flow ends, then lets it go, so the parent needn't keep it.

```swift
router.present(AddressPickerCoordinator(), style: .sheet) { result in
    switch result {
    case .finished(let address):
        self.useAddress(address)
    case .cancelled:
        break   // the user swiped the sheet away
    }
}
```

> Warning: Waypoint keeps `onFinish:` with the child's flow until the flow ends. When it captures the parent coordinator, as a call to a named method does, the parent stays alive while the child is presented, even after the app lets it go. End the flow first, such as by dismissing it, or capture `[weak self]`.

The child ends the flow with `finish(with:)`, and the parent gets `.finished(value)`. Every other end is `.cancelled`: the user swipes the sheet away, the child calls `router.dismissFlow()`, a parent dismisses it or a flow above it, or the `.replacePresentation` fallback replaces it. A second `finish(with:)`, or a dismiss after it, delivers nothing more.

The lazy form builds the child only when the present happens, so a present that is refused, such as over a sheet already up, or ignored, on a router that left the tree, builds nothing, and a queued one builds it when it runs:

```swift
router.present(style: .sheet, onFinish: addressPicked) {
    AddressPickerCoordinator(addresses: addresses)
}
```

While the closure runs, the child's router is made inside the parent's tree, so a push from the child's `init` gets the tree's settings. Any other router made in the closure stays separate; one that took the child's place, such as another coordinator of the same type read first, is reported as `routerDetachedFromLazyStart`. A child whose own `makeRouter()` makes its router joins on start like one passed in.

A present that returns `.failed` or `.ignored` started no flow, so `onFinish:` is never called. A child whose router is the presenting router or one above it fails with `childRouterIsAncestor`, and one whose router is already in another tree, belongs to another coordinator or ended with an earlier flow fails with `routerInAnotherTree`. A tab router presents a child flow above the whole container the same way.

```swift
/// How a child flow ended.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
public enum FlowResult<Value: Sendable>: Sendable {
    case finished(Value)
    case cancelled
}

extension StackRouter {
    /// Presents a child flow, and gives its result to `onFinish` once.
    @discardableResult
    public func present<Child: FlowCoordinating>(
        _ child: Child,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void
    ) -> NavigationOutcome

    /// The same, building the child only when the present happens.
    @discardableResult
    public func present<Child: FlowCoordinating>(
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: @escaping @MainActor () -> Child
    ) -> NavigationOutcome
}
```

Like every navigation method, these take a file and line, left out here.

### Pushing a child flow

Pushing a child flow shows its screens on the parent's stack: the child's root screen first, then every screen the child's router pushes. The child's router is a child of the parent in the tree, with its own path of its own routes, and joins the tree as a presented child does. The parent's path holds one route for the whole child flow, so the parent's path never holds the child's routes:

```swift
router.push(ReviewCoordinator(product: product)) { result in
    // .finished(review), or .cancelled when the user went back past its first screen
}
```

The flow ends with `.cancelled` when the user goes back past the child's root screen, or when the parent changes its own path: a push, a pop or a `popTo` on the parent ends the child on top first, then does what was asked. Pushing a second child flow ends the first. `finish(with:)` and `dismissFlow()` in the child pop back to the screen below the child's root screen. A child flow that needs a stack of its own is presented. The lazy form, `router.push(onFinish:) { child }`, builds the child only when the push happens, as the lazy present does. Both push forms are in `Waypoint`, not in `WaypointCore`, and take a `FlowCoordinator`: the parent's stack draws the child's `root` for its marker, then the screens the child pushes from its `destinations`, so only a flow with screens can be pushed.

```swift
// In `Waypoint`:
extension StackRouter {
    @discardableResult
    public func push<Child: FlowCoordinator>(
        _ child: Child,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void
    ) -> NavigationOutcome

    @discardableResult
    public func push<Child: FlowCoordinator>(
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: @escaping @MainActor () -> Child
    ) -> NavigationOutcome
}
```

Still planned: `await router.present(child, style:)`, which returns the `FlowResult` (#60):

```swift
let result = await router.present(AddressPickerCoordinator(), style: .sheet)
```

To start a flow without passing its coordinator, give it a `Flow(...)` entry and call `router.show(_:)`.

### A flow that stands for a route

A flow can also stand for a route value, so a link, a held link or a restored state can open it. A `Flow(...)` entry in a coordinator's `destinations` registers a factory that builds the flow's coordinator, and its `onResult:` handler receives the flow's result, also after the app is relaunched with the flow restored. The entry can declare how the flow is shown, as any destination can, so `router.show(_:)` opens it without repeating the style:

```swift
private static let filterDetents: [SheetDetent] = [.medium, .large]

var destinations: some Destinations {
    Flow(FilterRoute.self, presentation: .sheet(detents: Self.filterDetents)) { _ in
        FilterCoordinator()
    } onResult: { result in
        self.filterEnded(result)
    }
}

func showFilters() {
    router.show(FilterRoute())
}
```

Leaving out `presentation:` pushes the flow. A pushed child flow shares its parent's stack and is drawn by its parent's renderer, and only a coordinator that starts a new stack gets one of its own. The `Flow(...)` entry and result delivery are built in #60, its factories in #152, and `show` in #12. See "Declared presentation" in <doc:PresentingFlows>.

### Finding coordinators in the tree

```swift
extension StackRouter {
    /// The root router of the whole tree.
    public var root: any NavigationRouter { get }

    /// The nearest coordinator of type `C` above this router.
    public func nearest<C: AnyObject>(_ type: C.Type) -> C?
}

/// What every router has in common.
///
/// Conformances:
/// - `AnyObject`, because every router is one shared object in the tree.
@MainActor
public protocol NavigationRouter: AnyObject {
    var flowID: FlowID { get }
    var parent: (any NavigationRouter)? { get }
    var children: [any NavigationRouter] { get }
    var isActive: Bool { get }

    func debugTree() -> String
}
```
