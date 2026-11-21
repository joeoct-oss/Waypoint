# Root switching

Swap whole flows, such as login and the main tabs.

## Overview

> Note: Draft until #37. The API in this article is planned, not built, and can still change when #37 and #59 land.

Apps replace their whole screen at a few moments: from launch to login, from login to the main tabs, and back to login on logout. `RootRouter` holds which root is showing and replaces the whole subtree when it switches. The old flow and every router inside it are released.

```swift
// Conformances:
// - `NavigationRoot`, so `RootRouter` can compare roots to know when to switch, save and restore
//   the current root, and name it in events off the main actor.
enum AppRoot: NavigationRoot {
    case login
    case main
}
```

Root types conform to `NavigationRoot`, which is `Hashable`, `Codable` and `Sendable` under one name. See <doc:WhyTheseConformances>.

### The app coordinator decides

The root router belongs to your app coordinator (see <doc:CoordinatorsAndChildFlows>). Screens never switch the root. The login screen reports that the user logged in, and the app coordinator decides what happens next:

```swift
// Conformances:
// - `RootCoordinator`, so it owns the app's root router and link inbox, and Waypoint can draw it.
final class AppCoordinator: RootCoordinator {
    let router = RootRouter(AppRoot.login)
    let links: LinkInbox?

    init() {
        let hosts: Set<String> = ["example.com"]
        let schemes: Set<String> = ["myshop"]
        self.links = LinkInbox(domains: LinkDomains(hosts: hosts, schemes: schemes))
    }

    func showMainFlow() {
        router.switch(to: .main)
        links?.markReady()
    }

    func showLoginFlow() {
        links?.markNotReady()
        router.switch(to: .login)
    }
}
```

The `Waypoint` product adds the flow for each root: `makeFlow(for:)` returns the coordinator of the root's flow, and Waypoint draws its `view` with the renderer chosen for it. There is one `RootCoordinator` for SwiftUI and UIKit apps. The rules stay in plain Swift, so you test them without drawing anything:

```swift
@Test @MainActor
func loggingInShowsTheMainTabs() {
    let app = AppCoordinator()

    app.showMainFlow()

    #expect(app.router.current == .main)
}
```

### The root router

```swift
/// A root of the app, usually an app enum such as `AppRoot`.
///
/// Conformances:
/// - `NavigationValue`, so roots can be compared to know when to switch, the current root is
///   saved and restored, and it is named in events off the main actor.
public protocol NavigationRoot: NavigationValue { }

/// The owner of the app's top-level flow.
///
/// Conformances:
/// - `NavigationRouter`, so it takes part in the router tree.
/// - `Root: NavigationRoot`, the app's root type.
@MainActor @Observable
public final class RootRouter<Root: NavigationRoot>: NavigationRouter {
    /// The root that is showing.
    public var current: Root { get }

    /// What to do when a call fails. Inherited by every router below this one.
    public var fallbackPolicy: FallbackPolicy { get }
    /// Default options for presentations. Inherited by every router below this one.
    public var presentationDefaults: PresentationDefaults { get }

    /// Creates a root router showing `initial`.
    ///
    /// `configuration` holds the settings of the whole tree, such as logging and
    /// the failure handler. See <doc:StackNavigation>.
    public init(
        _ initial: Root,
        configuration: NavigationConfiguration = .default,
        file: StaticString = #fileID,
        line: UInt = #line
    )

    /// Sets one kind's fallback for every router below this one.
    public func setFallback(
        _ fallback: NavigationFallback?,
        for kind: NavigationIssue.Kind,
        file: StaticString = #fileID,
        line: UInt = #line
    )
    /// Sets the default presentation options for every router below this one.
    public func setPresentationDefaults(_ defaults: PresentationDefaults)

    /// Replaces the whole tree below this router with the flow for `root`.
    ///
    /// Everything presented is dismissed first. Returns `.alreadyThere` if
    /// `root` is showing. Emits a `rootChanged` event.
    @discardableResult
    public func `switch`(
        to root: Root,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome
}
```

The app coordinator's `makeFlow(for:)` decides which flow each root shows:

```swift
// What the `Waypoint` product adds to `RootCoordinator`. The router and the inbox are above.
//
// Conformances:
// - `AnyObject`, because a coordinator is one shared object that owns its router.
@MainActor
public protocol RootCoordinator: AnyObject {
    /// Conformances:
    /// - `RootFlow`: a coordinator that can fill the window, such as a stack or tab coordinator.
    associatedtype RootFlowCoordinator: RootFlow
    /// Conformances:
    /// - `RootRenderer`: what draws this coordinator. Default: `DefaultRootRenderer`.
    associatedtype Renderer: RootRenderer = DefaultRootRenderer

    /// The window's content, drawn by `Renderer`. Default: filled in by Waypoint.
    var view: Renderer { get }

    /// Returns the coordinator of the flow that `root` shows. Waypoint calls it once each time
    /// the root switches, inside `switch(to:)`, so the new flow and its routers are in the
    /// tree before `switch(to:)` returns and before the inbox applies a held link. Waypoint
    /// then draws the coordinator's `view`.
    @RootFlowBuilder func makeFlow(for root: Root) -> RootFlowCoordinator
}
```

`makeFlow(for:)` has a `switch` with one `make…Flow()` call per root, and each case can return a different kind of coordinator, as `@ViewBuilder` allows different views. The names `RootFlow`, `RootFlowCoordinator` and `RootFlowBuilder` are drafts, settled in #37. See "Coordinators and renderers" in the `Waypoint` catalog for the window entries. `RootRouter` can also be used on its own, as a lower-level building block, but the app coordinator is the place to start.

### Resuming a link after login

A deep link that arrives while the user is logged out is parked, not lost. When the root switches and the new flow is ready, the parked plan resumes in one step. See <doc:DeepLinks>.
