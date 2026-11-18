# Coordinators and child flows

Group screens into flows, nest them, and get a result back when a flow ends.

## Overview

> Note: Draft until #36. The API in this article is planned, not built, and can still change when #36 lands.

A coordinator is your own object that owns one router, the flow's dependencies and its logic. Screens report what happened through outputs, closures you pass in, and the coordinator decides where to go next. Screens never import Waypoint.

Coordinators are optional. A plain stack with a few `.destination` lines needs none. Add one when a flow has logic or dependencies worth keeping in one place.

```swift
// Conformances:
// - `StackCoordinator`: it adds screen building to a stack coordinator.
final class ShopCoordinator: StackCoordinator {
    let router = StackRouter()
    let catalog: CatalogService

    init(catalog: CatalogService) {
        self.catalog = catalog
    }

    func showProduct(_ id: Int) {
        router.push(ProductRoute(id: id))
    }
}
```

The renderer products add the parts that build screens: SwiftUI views or UIKit view controllers. See the renderer articles.

### Coordinator protocols

```swift
/// App code that owns one stack flow.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol StackCoordinator: AnyObject {
    /// The router this coordinator owns.
    var router: StackRouter { get }
}

/// App code that owns a tab container.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol TabCoordinator: AnyObject {
    associatedtype Tab: NavigationTab
    var router: TabRouter<Tab> { get }
}

/// A flow that ends with a value for whoever started it.
///
/// Conformances:
/// - `AnyObject`, because the flow is one object that ends once.
@MainActor
public protocol FlowFinishing: AnyObject {
    /// What the flow hands back, such as a picked address.
    associatedtype Output: Sendable

    /// Ends the flow with `output`. Its router is removed and released.
    func finish(with output: Output)
}
```

### The app coordinator

An app with more than one root flow, such as login and the main tabs, keeps its navigation in an app coordinator: your own type at the top of the coordinator tree. It owns the root router, the tab router, the child coordinators that live as long as the app, and the link inbox. It also decides what happens between flows. The `App` or scene delegate only creates it and hands it to the renderer, and screens report what happened instead of switching roots themselves.

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

    /// The router this coordinator owns.
    var router: RootRouter<Root> { get }

    /// Where incoming links go, or `nil` if the app takes no links.
    ///
    /// There is no default, so every app says which it means.
    var links: LinkInbox? { get }
}
```

The renderer products add the screens for each root: `SwiftUIRootCoordinator` and `UIKitRootCoordinator`. See <doc:RootSwitching> for a whole app coordinator.

Create child coordinators once and keep them in their parent coordinator, not inside a view's `body`, so a flow keeps its state while the screen redraws.

### A coordinator as its own flow type

A coordinator can be its own `NavigationFlow`. Routes then name it as their flow, and the coordinator gets a scoped handle for free. A separate empty `enum ShopFlow: NavigationFlow { }` works just as well. Neither is required.

```swift
// Conformances:
// - `StackCoordinator`: it adds screen building to a stack coordinator.
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

Presenting or pushing a child coordinator creates a child router in the tree. When the child flow ends, its router is removed and released.

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
    public func present<C: StackCoordinator & FlowFinishing>(
        _ child: C,
        style: PresentationStyle = .sheet
    ) async -> FlowResult<C.Output>

    /// The same, with a callback instead of `await`.
    @discardableResult
    public func present<C: StackCoordinator & FlowFinishing>(
        _ child: C,
        style: PresentationStyle = .sheet,
        else fallback: NavigationFallback? = nil,
        onFinish: @escaping @MainActor (FlowResult<C.Output>) -> Void
    ) -> NavigationOutcome

    /// Presents a child flow that returns nothing.
    @discardableResult
    public func present<C: StackCoordinator>(
        _ child: C,
        style: PresentationStyle = .sheet,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// Pushes a child flow's first screen onto this stack. The child shares
    /// this stack but has its own router for its own routes.
    @discardableResult
    public func push<C: StackCoordinator>(_ child: C, else fallback: NavigationFallback? = nil) -> NavigationOutcome
}
```

Like every navigation method, these take an optional fallback, file and line, left out here.

> Note: Two changes are coming to child flows. A pushed child coordinator shares its parent's stack and container, and only a coordinator that starts a new stack gets a container of its own. A flow will also be able to stand for a route value, registered with a factory that builds its coordinator, so a link, a held link or a restored state can open it. A parent will then receive a flow's result through a handler registered by flow type, so a result still arrives after the app is relaunched. Tracked in #151 and #152.

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
