# Navigating from views and view models

Pick the style that suits your team: outputs, injected navigators or property wrappers.

## Overview

There is one router and three ways to reach it. All three call the same router methods, so guards, events, outcomes and restoration behave the same whichever you use, and you can mix them in one app.

| Style | The screen knows about | Best for |
|---|---|---|
| Outputs | Nothing from Waypoint | Coordinators, reusable screens |
| Injected navigator | `StackNavigator` or `FlowNavigator<Flow>` from `WaypointCore` | View models that decide navigation and are tested without SwiftUI |
| Property wrappers | The environment router | Views that navigate on their own |

### Outputs

The screen reports what happened, and whoever made it decides where to go:

```swift
struct ProductView: View {
    let id: Int
    var onBuy: () -> Void
    var body: some View { Button("Buy", action: onBuy) }
}

.destination(ProductRoute.self) { route in
    ProductView(id: route.id, onBuy: { router.push(CartRoute()) })
}
```

### Injected navigators

The destination closure hands over a navigator, and the view model keeps it:

```swift
.destination(ProductRoute.self) { route, navigation in
    ProductView(model: ProductModel(id: route.id, navigation: navigation))
}
```

A view model that only accepts its own flow's routes takes a `FlowNavigator<Flow>`. The compiler then refuses a push of another flow's route.

### Property wrappers

They are thin, read the router from the environment, and hold no state of their own. All are optional.

```swift
/// The nearest stack's navigator.
@propertyWrapper public struct StackNavigation: DynamicProperty {
    public init()
    public var wrappedValue: StackNavigator { get }
}

/// The nearest stack of `Flow`, even from a sheet inside it.
@propertyWrapper public struct FlowNavigation<Flow: NavigationFlow>: DynamicProperty {
    public init(_ flow: Flow.Type)
    public var wrappedValue: FlowNavigator<Flow> { get }
}

/// Dismisses the flow this view is in.
@propertyWrapper public struct DismissFlow: DynamicProperty {
    public init()
    public var wrappedValue: DismissFlowAction { get }
}

/// Ends the flow this view is in with a result.
@propertyWrapper public struct FinishFlow<Flow: FlowFinishing>: DynamicProperty {
    public init(_ flow: Flow.Type)
    public var wrappedValue: FinishFlowAction<Flow.Output> { get }
}

/// The selected tab, settable. `$tab` is a `Binding`.
@propertyWrapper public struct TabSelection<Tab: Hashable & Codable & Sendable>: DynamicProperty {
    public init(_ tab: Tab.Type)
    public var wrappedValue: Tab { get nonmutating set }
    public var projectedValue: Binding<Tab> { get }
}

/// Switches the app's root.
@propertyWrapper public struct SwitchRoot<Root: Hashable & Codable & Sendable>: DynamicProperty {
    public init(_ root: Root.Type)
    public var wrappedValue: SwitchRootAction<Root> { get }
}

@MainActor public struct DismissFlowAction {
    @discardableResult public func callAsFunction() -> NavigationOutcome
}
@MainActor public struct FinishFlowAction<Output: Sendable> {
    public func callAsFunction(_ output: Output)
}
@MainActor public struct SwitchRootAction<Root: Hashable & Codable & Sendable> {
    @discardableResult public func callAsFunction(to root: Root) -> NavigationOutcome
}
```

```swift
struct ProductView: View {
    @FlowNavigation(ShopFlow.self) private var shop
    @DismissFlow private var dismissFlow

    var body: some View {
        Button("Add to cart") { shop.push(CartRoute()) }
        Button("Close") { dismissFlow() }
    }
}
```

The types are checked by the compiler. Whether a matching router is above the view can only be checked at run time. If none is, the wrapper reports an issue that names the view and the fix, shows the debug placeholder, and does nothing in release builds. `@Environment(StackRouter.self)` also works if you prefer the router itself.
