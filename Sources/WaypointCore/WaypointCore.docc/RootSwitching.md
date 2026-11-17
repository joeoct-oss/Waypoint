# Root switching

Swap whole flows, such as login and the main tabs.

## Overview

Apps replace their whole screen at a few moments: from launch to login, from login to the main tabs, and back to login on logout. `RootRouter` holds which root is showing and replaces the whole subtree when it switches. The old flow and every router inside it are released.

```swift
enum AppRoot: Hashable, Codable, Sendable { case login, main }

let root = RootRouter(AppRoot.login)
root.switch(to: .main)
```

### The root router

```swift
/// The owner of the app's top-level flow.
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

The renderers decide which screen or coordinator each root shows. See the renderer articles.

### Resuming a link after login

A deep link that arrives while the user is logged out is parked, not lost. When the root switches and the new flow is ready, the parked plan resumes in one step. See <doc:DeepLinks>.
