# Testing your navigation

Test coordinators and view models without a UI, on any platform Swift runs on.

## Overview

> Note: Draft until #41. The API in this article is planned, not built, and can still change when #41 lands.

Routers are plain objects, so most navigation tests need no simulator. Create a real router, call your code, and check the state.

The registry is strict, so a route type with no destination is rejected in tests as it is in the app. A test with no renderer either registers the routes it pushes, as below, or asks for `NavigationConfiguration(registry: .permissive)` by name. See <doc:Routes>.

```swift
@Test @MainActor
func buyPushesCart() {
    let router = StackRouter()
    router.register(CartRoute.self)
    let model = ProductModel(navigation: router.navigator(for: ShopFlow.self))

    model.buy()

    #expect(router.last(CartRoute.self) != nil)
}
```

The `WaypointTesting` library adds helpers for the checks you write most. It will be its own product with its own documentation catalog. This article fixes its shape.

### Swift Testing and XCTest

The helpers work in both. Inside a Swift Testing test a failure is recorded as a Swift Testing issue. Anywhere else it is reported with `XCTFail`, at the same file and line. Your test reads the same either way:

```swift
final class ProductModelTests: XCTestCase {
    @MainActor
    func testBuyPushesCart() {
        let router = StackRouter()
        router.register(CartRoute.self)
        let model = ProductModel(navigation: router.navigator(for: ShopFlow.self))

        model.buy()

        expectPath(router) {
            CartRoute()
        }
    }
}
```

Strict mode reports failures the same way.

Failure messages print routes with their values, such as `ProductRoute(id: 42)`, because a test needs to see what it compares. Logs keep them private. See <doc:Descriptions>.

### Assertions

```swift
/// Checks a stack's whole path.
@MainActor
public func expectPath(
    _ router: StackRouter,
    @RoutePathBuilder _ path: () -> [AnyRoute],
    sourceLocation: SourceLocation = #_sourceLocation
)

/// Checks that a flow of type `C` is presented above `router`.
@MainActor
public func expectPresented<C: AnyObject>(
    _ router: some NavigationRouter,
    _ type: C.Type,
    sourceLocation: SourceLocation = #_sourceLocation
)

/// Checks what a call returned.
public func expectOutcome(
    _ outcome: NavigationOutcome,
    _ expected: NavigationOutcome,
    sourceLocation: SourceLocation = #_sourceLocation
)

/// Checks that every route type in `types` has a destination.
@MainActor
public func expectDestinations<Payload>(
    for table: RouteTable<Payload>,
    cover types: [any Route.Type],
    sourceLocation: SourceLocation = #_sourceLocation
)
```

### Recording events

```swift
/// Records every event and issue it observes.
///
/// Conformances:
/// - `NavigationObserver`, so routers send it every event to record.
@MainActor
public final class RecordingObserver: NavigationObserver {
    public var events: [NavigationEvent] { get }
    public var issues: [NavigationIssue] { get }

    public init()
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
        /// A call whose outcome is `.failed`.
        case failed
        /// A call that failed and was saved by its fallback.
        case recovered
        /// A call on a navigator whose flow is gone.
        case ignored
    }

    /// Default: `[.failed]`.
    public init(failOn: Set<Trigger> = [.failed])
}

extension NavigationRouter {
    /// Turns on strict mode for this router and everything below it.
    public func enableStrictMode(_ mode: StrictMode = StrictMode())
}
```
