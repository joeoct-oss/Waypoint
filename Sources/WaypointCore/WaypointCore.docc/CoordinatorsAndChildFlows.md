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

A stack or flow coordinator doesn't declare its router. Waypoint makes it the first time it is read, names it after the coordinator, and releases it when the flow ends. A coordinator that declares `let router = StackRouter()` uses its own, as tests do.

There is one coordinator protocol for each kind, and it is the same in SwiftUI and UIKit apps. The `Waypoint` product adds the screens: `root` and `destinations`, which take SwiftUI views or UIKit view controllers, and `view`, the whole flow drawn by a renderer you can choose. See "Coordinators and renderers" in the `Waypoint` catalog. The parts below have no UI, so a coordinator's logic is tested on Linux.

### Coordinator protocols

```swift
/// App code that owns one stack flow.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol StackCoordinator: AnyObject {
    /// The router this coordinator owns. Default: made the first time it is read.
    var router: StackRouter { get }
}

/// App code that owns a tab container, with one stack coordinator for each tab.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol TabCoordinator: AnyObject {
    /// Conformances:
    /// - `NavigationTab`, the app's tab type.
    associatedtype Tab: NavigationTab

    /// The router this coordinator owns. No default, because only the app knows which tab
    /// is selected first, such as `let router = TabRouter(selection: MainTab.home)`.
    var router: TabRouter<Tab> { get }
}

/// App code that owns a child flow, presented or pushed, that ends with a value for whoever
/// started it.
///
/// Conformances:
/// - `AnyObject`, because the flow is one object that ends once.
@MainActor
public protocol FlowCoordinator: AnyObject {
    /// What the flow hands back, such as a picked address.
    associatedtype Output: Sendable

    /// The router this coordinator owns. Default: made the first time it is read.
    var router: StackRouter { get }

    /// Ends the flow with `output`. Waypoint delivers the result, dismisses the flow, and
    /// releases its router and coordinator. Default: filled in by Waypoint.
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

A child coordinator's router joins its parent's tree before any call or link reaches the parent: a tab's stack coordinator joins the tab router as soon as the tab coordinator joins the tree, and a presented or pushed child joins when it starts. A router read earlier, such as in a test, works on its own and keeps its screens when it joins. Waypoint has to know which stack coordinator belongs to which tab before the tabs are drawn. How the tab coordinator tells it, a requirement that maps each tab to its coordinator or a rule over `makeTabFlow(for:)`, is designed in #59.

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

A child flow is a `FlowCoordinator`. Presenting or pushing one creates a child router in the tree. When the child flow ends, its router is removed and released.

```swift
let result = await router.present(AddressPickerCoordinator(), style: .sheet)
switch result {
case .finished(let address):
    useAddress(address)
case .cancelled:
    break   // the user swiped the sheet away
}
```

```swift
/// How a child flow ended.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Value: Sendable`, because the result travels from the child flow to the task that awaits it.
public enum FlowResult<Value: Sendable>: Sendable {
    case finished(Value)
    case cancelled
}

extension StackRouter {
    /// Presents a child flow and waits for its result.
    ///
    /// The result is delivered exactly once: when the flow calls `finish(with:)`,
    /// when it is dismissed in code, or when the user swipes it away.
    public func present<C: FlowCoordinator>(
        _ child: C,
        style: PresentationStyle = .sheet
    ) async -> FlowResult<C.Output>

    /// The same, with a callback instead of `await`.
    @discardableResult
    public func present<C: FlowCoordinator>(
        _ child: C,
        style: PresentationStyle = .sheet,
        else fallback: NavigationFallback? = nil,
        onFinish: @escaping @MainActor (FlowResult<C.Output>) -> Void
    ) -> NavigationOutcome

    /// Pushes a child flow's first screen onto this stack. The child shares
    /// this stack but has its own router for its own routes.
    @discardableResult
    public func push<C: FlowCoordinator>(
        _ child: C,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
}
```

Like every navigation method, these take an optional fallback, file and line, left out here. To start a flow without waiting for its result, give it a `Flow(...)` entry and call `router.show(_:)`, or use the `onFinish:` form.

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
