# Root switching

Swap whole flows, such as login and the main tabs.

## Overview

Apps replace their whole screen at a few moments: from launch to login, from login to the main tabs, and back to login on logout. `RootRouter` holds which root is showing and replaces the whole subtree when it switches. The old flow and every router inside it are released.

```swift
// Conformances:
// - `Hashable`, required by `RootRouter`, which compares roots to know when to switch.
// - `Codable`, required by `RootRouter`, which saves and restores the current root with the tree.
// - `Sendable`, required by `RootRouter`, so events that name the root can leave the main actor.
enum AppRoot: Hashable, Codable, Sendable {
    case login
    case main
}
```

Root types need `Hashable`, `Codable` and `Sendable`. See <doc:WhyTheseConformances>.

### The app coordinator decides

The root router belongs to your app coordinator (see <doc:CoordinatorsAndChildFlows>). Screens never switch the root. The login screen reports that the user logged in, and the app coordinator decides what happens next:

```swift
// Conformances:
// - `RootCoordinator`, so it owns the app's root router and link inbox.
final class AppCoordinator: RootCoordinator {
    let router = RootRouter(AppRoot.login)
    let links: LinkInbox? = LinkInbox(domains: LinkDomains(hosts: ["example.com"], schemes: ["myshop"]))

    func didLogIn() {
        router.switch(to: .main)
        links?.isReady = true
    }

    func didLogOut() {
        links?.isReady = false
        router.switch(to: .login)
    }
}
```

The renderer protocols, `SwiftUIRootCoordinator` and `UIKitRootCoordinator`, add the screens for each root. The rules stay in plain Swift, so you test them without drawing anything:

```swift
@Test @MainActor
func loggingInShowsTheMainTabs() {
    let app = AppCoordinator()

    app.didLogIn()

    #expect(app.router.current == .main)
}
```

### The root router

```swift
/// The owner of the app's top-level flow.
///
/// Conformances:
/// - `NavigationRouter`, so it takes part in the router tree.
/// - `Root: Hashable`, to compare roots.
/// - `Root: Codable`, so the current root is saved and restored.
/// - `Root: Sendable`, so root events can leave the main actor.
@MainActor @Observable
public final class RootRouter<Root: Hashable & Codable & Sendable>: NavigationRouter {
    /// Creates a root router showing `initial`.
    ///
    /// `logging` sets how the whole tree logs. See <doc:EventsAndLogging>.
    public init(_ initial: Root, logging: LogConfiguration = .default)

    /// The root that is showing.
    public private(set) var current: Root

    /// Replaces the whole tree below this router with the flow for `root`.
    ///
    /// Everything presented is dismissed first. Returns `.alreadyThere` if
    /// `root` is showing. Emits a `rootChanged` event.
    @discardableResult
    public func `switch`(to root: Root, file: StaticString = #fileID, line: UInt = #line) -> NavigationOutcome

    /// Called when a call fails and its fallback fails too, anywhere in the tree.
    public func onNavigationFailure(_ handler: @escaping @MainActor (NavigationFailure) -> Void)

    public var fallbackPolicy: FallbackPolicy { get set }
    public var presentationDefaults: PresentationDefaults { get set }
}
```

The app coordinator's renderer protocol decides which screen or flow each root shows. See the renderer articles. `RootRouter` can also be used on its own, as a lower-level building block, but the app coordinator is the place to start.

### Resuming a link after login

A deep link that arrives while the user is logged out is parked, not lost. When the root switches and the new flow is ready, the parked plan resumes in one step. See <doc:DeepLinks>.
