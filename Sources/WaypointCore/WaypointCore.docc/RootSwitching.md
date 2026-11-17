# Root switching

Swap whole flows, such as login and the main tabs.

## Overview

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
// - `RootCoordinator`, so it owns the app's root router and link inbox.
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

The renderer protocols, `SwiftUIRootCoordinator` and `UIKitRootCoordinator`, add the screens for each root. The rules stay in plain Swift, so you test them without drawing anything:

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
    /// `logging` sets how the whole tree logs. See <doc:EventsAndLogging>.
    public init(_ initial: Root, logging: LogConfiguration = .default)

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
    public func `switch`(to root: Root, file: StaticString = #fileID, line: UInt = #line) -> NavigationOutcome

    /// Called when a call fails and its fallback fails too, anywhere in the tree.
    public func onNavigationFailure(_ handler: @escaping @MainActor (NavigationFailure) -> Void)
}
```

The app coordinator's renderer protocol decides which screen or flow each root shows. See the renderer articles. `RootRouter` can also be used on its own, as a lower-level building block, but the app coordinator is the place to start.

### Resuming a link after login

A deep link that arrives while the user is logged out is parked, not lost. When the root switches and the new flow is ready, the parked plan resumes in one step. See <doc:DeepLinks>.
