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

    var body: some View {
        Button("Buy", action: onBuy)
    }
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
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
@propertyWrapper public struct StackNavigation: DynamicProperty {
    public var wrappedValue: StackNavigator { get }

    public init()
}

/// The nearest stack of `Flow`, even from a sheet inside it.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
/// - `Flow: NavigationFlow`: the flow whose routes are accepted.
@propertyWrapper public struct FlowNavigation<Flow: NavigationFlow>: DynamicProperty {
    public var wrappedValue: FlowNavigator<Flow> { get }

    public init(_ flow: Flow.Type)
}

/// Dismisses the flow this view is in.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
@propertyWrapper public struct DismissFlow: DynamicProperty {
    public var wrappedValue: DismissFlowAction { get }

    public init()
}

/// Ends the flow this view is in with a result.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
/// - `Flow: FlowFinishing`: the flow that ends with a result.
@propertyWrapper public struct FinishFlow<Flow: FlowFinishing>: DynamicProperty {
    public var wrappedValue: FinishFlowAction<Flow.Output> { get }

    public init(_ flow: Flow.Type)
}

/// The selected tab, settable. `$tab` is a `Binding`.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
@propertyWrapper public struct TabSelection<Tab: Hashable & Codable & Sendable>: DynamicProperty {
    public var wrappedValue: Tab { get nonmutating set }
    public var projectedValue: Binding<Tab> { get }

    public init(_ tab: Tab.Type)
}

@MainActor public struct DismissFlowAction {
    @discardableResult public func callAsFunction() -> NavigationOutcome
}

/// Conformances:
/// - `Output: Sendable`, because the result travels from the child flow to the task that awaits
///   it.
@MainActor public struct FinishFlowAction<Output: Sendable> {
    public func callAsFunction(_ output: Output)
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

There is no wrapper for switching the app's root. That decision belongs to the app coordinator: a login screen reports that the user logged in, and the coordinator switches. See <doc:ExampleFlows>.

The types are checked by the compiler. Whether a matching router is above the view can only be checked at run time. If none is, the wrapper reports an issue that names the view and the fix, shows the debug placeholder, and does nothing in release builds. `@Environment(StackRouter.self)` also works if you prefer the router itself.
