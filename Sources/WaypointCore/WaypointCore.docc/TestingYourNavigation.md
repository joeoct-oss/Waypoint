# Testing your navigation

Test coordinators and view models without a UI, on any platform Swift runs on.

## Overview

Routers are plain objects, so most navigation tests need no simulator. Create a real router, call your code, and check the state.

```swift
@Test @MainActor
func buyPushesCart() {
    let router = StackRouter()
    let model = ProductModel(navigation: router.navigator(for: ShopFlow.self))

    model.buy()

    #expect(router.last(CartRoute.self) != nil)
}
```

The `WaypointTesting` library adds helpers for the checks you write most. It will be its own product with its own documentation catalog. This article fixes its shape.

### Assertions

```swift
/// Checks a stack's whole path.
@MainActor
public func expectPath(_ router: StackRouter, @RoutePathBuilder _ path: () -> [AnyRoute],
                       sourceLocation: SourceLocation = #_sourceLocation)

/// Checks that a flow of type `C` is presented above `router`.
@MainActor
public func expectPresented<C: AnyObject>(_ router: some NavigationRouter, _ type: C.Type,
                                          sourceLocation: SourceLocation = #_sourceLocation)

/// Checks what a call returned.
public func expectOutcome(_ outcome: NavigationOutcome, _ expected: NavigationOutcome,
                          sourceLocation: SourceLocation = #_sourceLocation)

/// Checks that every route type in `types` has a destination.
@MainActor
public func expectDestinations<Payload>(for table: RouteTable<Payload>, cover types: [any Route.Type],
                                        sourceLocation: SourceLocation = #_sourceLocation)
```

### Recording events

```swift
/// Records every event and issue it observes.
///
/// Conformances:
/// - `NavigationObserver`, so routers send it every event to record.
@MainActor
public final class RecordingObserver: NavigationObserver {
    public init()
    public private(set) var events: [NavigationEvent]
    public private(set) var issues: [NavigationIssue]
}
```

### Simulating the user

A simulated renderer sends the same reports a real one does when the user swipes back, drags a sheet down or taps a tab.

```swift
@MainActor
public struct SimulatedRenderer {
    public init()
    public func swipeBack(on router: StackRouter, count: Int = 1)
    public func dragSheetDown(on router: some NavigationRouter)
    public func dragSheet(on router: some NavigationRouter, to detent: SheetDetent)
    public func tapTab<Tab>(_ tab: Tab, on router: TabRouter<Tab>)
}
```

### Strict mode

In strict mode, a navigation call whose outcome is `.failed` fails the current test, with the file and line of the call. You choose how strict to be:

```swift
/// Fails tests on bad navigation calls.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct StrictMode: Sendable {
    /// Conformances:
    /// - `Sendable`, because `StrictMode` is `Sendable`.
    public enum Trigger: Sendable {
        case failed
        case recovered
    }
    /// Default: `[.failed]`.
    public init(failOn: Set<Trigger> = [.failed])
}

extension NavigationRouter {
    /// Turns on strict mode for this router and everything below it.
    public func enableStrictMode(_ mode: StrictMode = StrictMode())
}
```
