# The SwiftUI renderer

Show stacks, sheets, tabs and roots in SwiftUI.

## Overview

Each entry view takes a router, or makes one for you, and draws its state. Screens are registered by route type. SwiftUI applies one `navigationDestination(for:)` per registered type, so screens are never wrapped in `AnyView`.

The renderer keeps no navigation state of its own. It mirrors the router's path into a `NavigationPath` and reports user pops, sheet dismissals, sheet size changes and tab taps back to the router.

### Stacks

```swift
/// A navigation stack driven by a `StackRouter`.
///
/// Conformances:
/// - `Root: View`: the stack's first screen.
public struct WaypointStack<Root: View>: View {
    /// Creates a stack with its own router.
    public init(@ViewBuilder root: () -> Root)

    /// Creates a stack for a router you own.
    public init(_ router: StackRouter, @ViewBuilder root: () -> Root)

    /// Creates a stack that belongs to a flow, so `@FlowNavigation(Flow.self)`
    /// finds it.
    public init<F: NavigationFlow>(flow: F.Type, router: StackRouter? = nil, @ViewBuilder root: () -> Root)
}

extension View {
    /// Shows `route`'s screen when a route of type `R` is pushed or presented.
    public func destination<R: Route, Content: View>(
        _ type: R.Type,
        @ViewBuilder _ content: @escaping (R) -> Content
    ) -> some View

    /// The same, and also hands the screen a navigator for its view model.
    public func destination<R: Route, Content: View>(
        _ type: R.Type,
        @ViewBuilder _ content: @escaping (R, StackNavigator) -> Content
    ) -> some View
}
```

A route with no destination never crashes. Debug builds show a "No destination for …" screen that names the route and the fix, and release builds refuse the push.

### The Waypoint link

Use `WaypointLink` for a tappable row that pushes a route. It calls `router.push`, so the push is recorded like any other.

```swift
/// A button that pushes a route onto the nearest Waypoint stack.
///
/// Conformances:
/// - `Label: View`: what SwiftUI shows.
/// - `R: Route`: the route type this works with.
public struct WaypointLink<Label: View, R: Route>: View {
    public init(_ route: R, @ViewBuilder label: () -> Label)
}

extension WaypointLink where Label == Text {
    public init(_ title: LocalizedStringKey, route: R)
}
```

> Important: Don't use `NavigationLink(value:)` inside a Waypoint stack. SwiftUI hands the stack a new path entry that can't be read back as a route. Debug builds report it as an issue. `NavigationLink(destination:)` for a screen outside Waypoint's routes still works.

### Coordinators

A coordinator gives a flow its root screen and its destinations in one place.

```swift
/// A stack coordinator that draws with SwiftUI.
///
/// Conformances:
/// - `StackCoordinator`: it adds screen building to a stack coordinator.
public protocol SwiftUIStackCoordinator: StackCoordinator {
    associatedtype RootView: View
    associatedtype Body: Destinations
    @ViewBuilder var root: RootView { get }
    @DestinationsBuilder var destinations: Body { get }
}

/// Registers one route type's screen inside a coordinator.
///
/// Conformances:
/// - `Destinations`, so it can be listed in a coordinator's destinations.
/// - `R: Route`: the route type this works with.
/// - `Content: View`: what SwiftUI shows.
public struct Destination<R: Route, Content: View>: Destinations {
    public init(_ type: R.Type, @ViewBuilder _ content: @escaping (R) -> Content)
    public init(_ type: R.Type, @ViewBuilder _ content: @escaping (R, StackNavigator) -> Content)
}

/// A group of destinations, built with `@DestinationsBuilder`.
public protocol Destinations { }

@resultBuilder
public enum DestinationsBuilder {
    /* blocks, conditions and loops */
}

extension WaypointStack {
    /// Draws a coordinator's flow.
    public init<C: SwiftUIStackCoordinator>(_ coordinator: C) where Root == C.RootView
}
```

```swift
// Conformances:
// - `SwiftUIStackCoordinator`, so `WaypointStack` can draw it.
final class ShopCoordinator: SwiftUIStackCoordinator {
    let router = StackRouter()

    var root: some View {
        ProductListView(onSelect: { self.router.push(ProductRoute(id: $0)) })
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { ProductView(id: $0.id, onBuy: { self.router.push(CartRoute()) }) }
        Destination(CartRoute.self) { _ in CartView() }
    }
}

WaypointStack(ShopCoordinator())
```

### Sheets and full-screen covers

Presentations are drawn from router state. A presented route uses the destination registered for its type, and a presented coordinator draws its own flow. Sheet sizes come from the presentation's `SheetOptions` and map to `PresentationDetent`:

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

```swift
/// A tab view driven by a `TabRouter`. Each tab gets its own stack.
///
/// Conformances:
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
/// - `Content: View`: what SwiftUI shows.
public struct WaypointTabs<Tab: Hashable & Codable & Sendable, Content: View>: View {
    public init(_ router: TabRouter<Tab>, @ViewBuilder content: @escaping (Tab) -> Content)
}

WaypointTabs(tabs, content: makeTabFlow(for:))
```

`makeTabFlow(for:)` is a function in your app coordinator with a `switch` over your tab enum, one `make…Flow()` call per case. That is fine here: it lists the tabs once, in one place, not every screen. See <doc:ExampleFlows>.

### Roots

An app coordinator draws each root. `WaypointRoot` draws the app coordinator, and the `App` holds nothing else:

```swift
/// An app coordinator that draws with SwiftUI.
///
/// Conformances:
/// - `RootCoordinator`: it adds a screen for each root to an app coordinator.
public protocol SwiftUIRootCoordinator: RootCoordinator {
    /// Conformances:
    /// - `View`: what SwiftUI shows for a root.
    associatedtype Content: View

    /// Builds the flow for one root.
    @ViewBuilder func makeFlow(for root: Root) -> Content
}

extension WaypointRoot {
    /// Draws an app coordinator's flow.
    ///
    /// If the coordinator has a link inbox, URL opens, universal links and
    /// user activities go to it, and its root router is attached.
    public init<C: SwiftUIRootCoordinator>(_ coordinator: C) where Root == C.Root, Content == C.Content
}
```

```swift
@main
struct ShopApp: App {
    @State private var app = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            WaypointRoot(app)
        }
    }
}
```

<doc:ExampleFlows> shows the whole `AppCoordinator`. The lower-level form draws a `RootRouter` with a closure:

```swift
/// Draws whichever root a `RootRouter` is showing.
///
/// Conformances:
/// - `Root: Hashable`, to compare roots.
/// - `Root: Codable`, so the current root is saved and restored.
/// - `Root: Sendable`, so root events can leave the main actor.
/// - `Content: View`: what SwiftUI shows.
public struct WaypointRoot<Root: Hashable & Codable & Sendable, Content: View>: View {
    public init(_ router: RootRouter<Root>, @ViewBuilder content: @escaping (Root) -> Content)
}
```

### Incoming links

`WaypointRoot(app)` wires the app coordinator's inbox, so most apps never call this. It is for apps that draw a `RootRouter` directly:

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
#Preview { ProductView(id: 1).waypointPreview() }

extension View {
    /// Wraps the view in a stack with a fresh router, so environment navigation works.
    public func waypointPreview() -> some View
}
```
