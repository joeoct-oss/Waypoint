# Coordinators and child flows

Group screens into flows, nest them, and get a result back when a flow ends.

## Overview

A coordinator is your own object that owns one router, the flow's dependencies and its logic. Screens report what happened through outputs, closures you pass in, and the coordinator decides where to go next. Screens never import Waypoint.

Coordinators are optional. A plain stack with a few `.destination` lines needs none. Add one when a flow has logic or dependencies worth keeping in one place.

```swift
final class ShopCoordinator: StackCoordinator {
    let router = StackRouter()
    let catalog: CatalogService
    init(catalog: CatalogService) { self.catalog = catalog }

    func showProduct(_ id: Int) { router.push(ProductRoute(id: id)) }
}
```

The renderer products add the parts that build screens: SwiftUI views or UIKit view controllers. See the renderer articles.

### Coordinator protocols

```swift
/// App code that owns one stack flow.
@MainActor
public protocol StackCoordinator: AnyObject {
    /// The router this coordinator owns.
    var router: StackRouter { get }
}

/// App code that owns a tab container.
@MainActor
public protocol TabCoordinator: AnyObject {
    associatedtype Tab: Hashable & Codable & Sendable
    var router: TabRouter<Tab> { get }
}

/// A flow that ends with a value for whoever started it.
@MainActor
public protocol FlowFinishing: AnyObject {
    /// What the flow hands back, such as a picked address.
    associatedtype Output: Sendable

    /// Ends the flow with `output`. Its router is removed and released.
    func finish(with output: Output)
}
```

### A coordinator as its own flow type

A coordinator can be its own `NavigationFlow`. Routes then name it as their flow, and the coordinator gets a scoped handle for free. A separate empty `enum ShopFlow: NavigationFlow { }` works just as well. Neither is required.

```swift
final class ShopCoordinator: StackCoordinator, NavigationFlow {
    ...
}
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
case .finished(let address): order.address = address
case .cancelled: break   // the user swiped the sheet away
}
```

```swift
/// How a child flow ended.
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
        _ child: C, style: PresentationStyle = .sheet
    ) async -> FlowResult<C.Output>

    /// The same, with a callback instead of `await`.
    @discardableResult
    public func present<C: StackCoordinator & FlowFinishing>(
        _ child: C, style: PresentationStyle = .sheet,
        onFinish: @escaping @MainActor (FlowResult<C.Output>) -> Void
    ) -> NavigationOutcome

    /// Presents a child flow that returns nothing.
    @discardableResult
    public func present<C: StackCoordinator>(_ child: C, style: PresentationStyle = .sheet) -> NavigationOutcome

    /// Pushes a child flow's first screen onto this stack. The child shares
    /// this stack but has its own router for its own routes.
    @discardableResult
    public func push<C: StackCoordinator>(_ child: C) -> NavigationOutcome
}
```

Like every navigation method, these take an optional fallback, file and line, left out here.

### Finding coordinators in the tree

```swift
extension StackRouter {
    /// The nearest coordinator of type `C` above this router.
    public func nearest<C: AnyObject>(_ type: C.Type) -> C?

    /// The root router of the whole tree.
    public var root: any NavigationRouter { get }
}

/// What every router has in common.
@MainActor
public protocol NavigationRouter: AnyObject {
    var flowID: FlowID { get }
    var parent: (any NavigationRouter)? { get }
    var children: [any NavigationRouter] { get }
    func debugTree() -> String
}
```
