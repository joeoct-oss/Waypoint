# The SwiftUI renderer

Show stacks, sheets, tabs and roots in SwiftUI.

## Overview

> Note: Stacks are built (#11): `WaypointStack`, `destination(_:_:)`, swipe-back sync and the Waypoint link (#147). So are the flow initializer, the navigator destination and previews (#25). The rest of this article is planned, not built, and can still change: coordinators (#36), sheets and full-screen covers (#12), tabs (#13), roots (#37, #148) and incoming links (#15).

Each entry view takes a router, or makes one for you, and draws its state. Screens are registered by route type. SwiftUI applies one `navigationDestination(for:)` per registered type, so screens are never wrapped in `AnyView`.

The renderer keeps no navigation state of its own. It mirrors the router's path into a `NavigationPath` and reports user pops back to the router. Sheet dismissals, sheet size changes and tab taps are reported the same way once sheets (#12) and tabs (#13) are built.

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
    /// finds it. The flow is declared on the router with `declareFlow(_:)`.
    public init<Flow: NavigationFlow>(
        flow: Flow.Type,
        router: StackRouter? = nil,
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

**Changes during a transition.** A multi-step push or pop runs as one animation. On iOS 17, SwiftUI drops a path change that lands while a push or pop still animates, so there the stack holds the change and shows the router's newest path when the transition ends (about 0.6 s). A change that replaces screens, such as a link from one product to another, is shown there as a pop back to the screens both paths share, then a push. Later systems apply every change at once.

**One push per tap.** The stack tells its router when it starts showing a push and when that push ends (about 0.6 s later), on every system. Until then, a second push of the same route, such as the second tap of a fast double tap on a row, is skipped and returns `.alreadyThere`. See "One push per tap" in the core's stack navigation article to turn it off.

A route with no destination never crashes. The registry is strict, so the router refuses a route type that no `destination(_:_:)` registered, with `unregisteredRoute` and the fallback you choose. Destinations register as the stack is first drawn, before any screen can push. A type registered in another stack of the tree but not in this one shows an empty screen; a debug screen that names the route and the fix is planned in #166.

> Note: Stack containers are changing. Waypoint will create the container itself wherever a coordinator starts a new stack: the app's root, a presented flow, a tab's root, or a flow shown from existing app code. Apps show a coordinator and never create or wire a container. A pushed child coordinator shares its parent's stack. A route's destination will be able to return a SwiftUI view or a UIKit view controller in either renderer. Apps still push routes, never views. Tracked in #151.

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
        ProductListView(onSelect: { self.showProduct(id: $0) })
    }

    var destinations: some Destinations {
        Destination(ProductRoute.self) { ProductView(id: $0.id, onBuy: { self.showCart() }) }
        Destination(CartRoute.self) { _ in CartView() }
    }

    func showProduct(id: Int) {
        router.push(ProductRoute(id: id))
    }

    func showCart() {
        router.push(CartRoute())
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
/// - `Tab: NavigationTab`, the app's tab type.
/// - `Content: View`: what SwiftUI shows.
public struct WaypointTabs<Tab: NavigationTab, Content: View>: View {
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
    /// Creates the app coordinator once for this window and draws its flow.
    ///
    /// Each window gets its own coordinator, so two windows on iPad never
    /// share a stack, a link inbox or saved state. If the coordinator has a
    /// link inbox, URL opens, universal links and user activities go to it,
    /// and its root router is attached.
    public init<C: SwiftUIRootCoordinator>(
        _ makeCoordinator: @escaping @MainActor () -> C
    ) where Root == C.Root, Content == C.Content
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
