# Navigating from views and view models

Pick the style that suits your team: outputs, injected navigators or property wrappers.

## Overview

> Note: Built in #25: the navigators, flow scoping, `WaypointStack(flow:)`, the navigator destination, `@StackNavigation`, `@FlowNavigation`, `@DismissFlow` and the preview helper. `@FinishFlow` lands with coordinators (#59) and `@TabSelection` with tabs (#13).

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
    let onBuy: () -> Void

    var body: some View {
        Button("Buy", action: onBuy)
    }
}

.destination(ProductRoute.self) { route in
    ProductView(id: route.id, onBuy: { router.push(CartRoute()) })
}
```

### Injected navigators

The destination closure hands over a `StackNavigator` for the screen it draws, and the view model keeps it:

```swift
.destination(ProductRoute.self) { route, navigation in
    ProductView(model: ProductModel(id: route.id, navigation: navigation))
}
```

A view model that only accepts its own flow's routes takes a `FlowNavigator<Flow>`. The compiler then refuses a push of another flow's route. Make one with `navigation.scoped(to: ShopFlow.self)`, or with `router.navigator(for: ShopFlow.self)` in a coordinator:

```swift
.destination(ProductRoute.self) { route, navigation in
    let shop = navigation.scoped(to: ShopFlow.self)
    ProductView(model: ProductModel(id: route.id, navigation: shop))
}
```

The view model imports only `WaypointCore` and is tested with a real router, on Linux too (see the core's Testing your navigation article). A navigator holds its router weakly and belongs to its screen: once the screen is popped or its flow is gone, every call returns `.ignored`, so a late network reply can't move another screen. A screen still on the stack keeps a live navigator, however many screens are pushed above it. The property wrappers below are read again on every draw, so theirs belong to the stack's root screen and live as long as the flow.

### Property wrappers

They are thin, read the router from the environment, and hold no state of their own. All are optional. `@FinishFlow` is planned with coordinators (#59), and `@TabSelection` with tabs (#13).

```swift
/// The nearest stack's navigator.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
@propertyWrapper public struct StackNavigation: DynamicProperty {
    public var wrappedValue: StackNavigator { get }

    public init(file: StaticString = #fileID, line: UInt = #line)
}

/// The nearest stack of `Flow`, even from a sheet inside it.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
/// - `Flow: NavigationFlow`: the flow whose routes are accepted.
@propertyWrapper public struct FlowNavigation<Flow: NavigationFlow>: DynamicProperty {
    public var wrappedValue: FlowNavigator<Flow> { get }

    public init(_ flow: Flow.Type, file: StaticString = #fileID, line: UInt = #line)
}

/// Dismisses the flow this view is in.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
@propertyWrapper public struct DismissFlow: DynamicProperty {
    public var wrappedValue: DismissFlowAction { get }

    public init(file: StaticString = #fileID, line: UInt = #line)
}

/// Ends the flow this view is in with a result.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
/// - `Flow: FlowCoordinator`: the flow that ends with a result.
@propertyWrapper public struct FinishFlow<Flow: FlowCoordinator>: DynamicProperty {
    public var wrappedValue: FinishFlowAction<Flow.Output> { get }

    public init(_ flow: Flow.Type)
}

/// The selected tab, settable. `$tab` is a `Binding`.
///
/// Conformances:
/// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
/// - `Tab: NavigationTab`, the app's tab type.
@propertyWrapper public struct TabSelection<Tab: NavigationTab>: DynamicProperty {
    public var wrappedValue: Tab { get nonmutating set }
    public var projectedValue: Binding<Tab> { get }

    public init(_ tab: Tab.Type)
}

@MainActor public struct DismissFlowAction {
    /// Whether the flow is still in the tree.
    public var isActive: Bool { get }

    @discardableResult public func callAsFunction(
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
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

A stack belongs to a flow when it is made with `WaypointStack(flow: ShopFlow.self)`, or when its router was declared with `router.declareFlow(ShopFlow.self)`. `@FlowNavigation(ShopFlow.self)` finds the nearest one.

The types are checked by the compiler. Whether a matching router is above the view can only be checked at run time. If none is, the wrapper's calls do nothing and return `.failed` with a `noRouterInScope` issue that names the wrapper, the file and line where it is declared, and the fix. The issue is also logged as a fault, so it shows in Xcode's console. Nothing crashes. A property wrapper can't swap its view for a placeholder, so the view itself draws as usual.

```text
@FlowNavigation(ShopFlow.self) in ProductView.swift:12 found no ShopFlow stack above its view.
Declare one with WaypointStack(flow: ShopFlow.self), or add .waypointPreview(flow: ShopFlow.self)
in its preview.
```

`@Environment(StackRouter.self)` also works if you prefer the router itself.

### Previews

A view that uses a wrapper needs a stack above it. In a preview, add one with a fresh router whose registry is permissive:

```swift
#Preview {
    HelpView()
        .waypointPreview()
}

#Preview {
    ProductView(id: 1)
        .waypointPreview(flow: ShopFlow.self)
}
```
