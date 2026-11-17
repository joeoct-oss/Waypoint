# Navigation state

Navigation is a tree of plain values that routers own and renderers draw.

## Overview

Everything on screen is described by value types: a stack's path, what it presents, which tab is selected. They are `Sendable`, `Equatable` and `Codable`, so you can compare them in tests, log them, save them and rebuild them.

Every field is a `let`, so a value can't change after it is made, and a value that breaks a rule can't be made: a tab state's selection is always one of its tabs, even when decoded. Routers own the state and are the only way to change it: each navigation call checks the change, then replaces the whole value. Renderers read it and report changes the user makes, such as a swipe back, but never keep their own copy.

```swift
let router = StackRouter()
router.push(ProductRoute(id: 42))

router.state.path        // [ProductRoute(id: 42)]
router.state.presentation // nil
```

### Stacks

```swift
/// The state of one navigation stack.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct StackState: Sendable, Equatable, Codable, NavigationDescribable {
    /// The routes pushed above the stack's root screen, bottom first.
    ///
    /// The root screen belongs to the stack itself, not the path, as in
    /// `NavigationStack(path:)`. An empty path shows the root screen.
    public let path: [AnyRoute]

    /// The flow this stack presents, if any.
    public let presentation: Presentation?
}
```

### Presentations

A flow presents at most one child flow at a time. The presented flow can present again, which gives a chain of modals, as in both SwiftUI and UIKit. See <doc:PresentingFlows> for styles and sheet sizes.

```swift
/// A child flow shown modally above its parent.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct Presentation: Sendable, Equatable, Codable, NavigationDescribable {
    /// How the flow is shown.
    public let style: PresentationStyle

    /// The presented flow.
    public let flow: FlowID

    /// The route of the presented flow's root screen, or `nil` when a
    /// coordinator builds the flow's root itself.
    public let route: AnyRoute?
}
```

### Tabs

```swift
/// The state of a tab container.
///
/// `Tab` is usually an app enum, such as a `MainTab` with `home`, `shop` and `profile` cases.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct TabState<Tab: Hashable & Codable & Sendable>: Sendable, Equatable, Codable, NavigationDescribable {
    /// The tabs, in display order.
    public let tabs: [Tab]

    /// The selected tab. Always one of `tabs`.
    public let selection: Tab

    /// The flow presented above the whole tab container, if any.
    public let presentation: Presentation?
}
```

### The whole tree

Each router has a stable `FlowID`. The erased form of the whole app's state is a `NavigationTree`, which is what snapshots, deep link plans and debug output use.

```swift
/// A stable name for one flow in the tree.
///
/// Stays the same across restoration, so events and snapshots can refer to it.
///
/// Conformances:
/// - `Hashable`, to find flows in the tree and key dictionaries by flow.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct FlowID: Hashable, Codable, Sendable, NavigationDescribable {
    /// The flow's name. Saved as a plain string.
    public let name: String

    /// Its `description` is the name, such as `shop`.
    public init(_ name: String)
}

/// The erased navigation state of every flow, from the root down.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationTree: Sendable, Equatable, Codable, NavigationDescribable {
    /// Conformances:
    /// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
    /// - `Equatable`, so tests and the router can compare values.
    /// - `Codable`, so it can be saved, restored and logged.
    public indirect enum Node: Sendable, Equatable, Codable {
        case stack(FlowID, StackState)
        case tabs(FlowID, selection: String, tabs: [String: NavigationTree])
        case root(FlowID, current: String, child: NavigationTree?)
    }
    /// The root flow and everything shown inside it.
    public let root: Node
    /// The flows presented over this one, by the flow that presented them.
    public let presented: [FlowID: NavigationTree]
}
```

### Changes

Every applied change is described by a value. Routers emit them as events, and tests can compare them.

```swift
/// One change to the navigation state.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public enum NavigationChange: Sendable, Equatable, NavigationDescribable {
    case pushed([AnyRoute])
    case popped([AnyRoute])
    case replaced(from: [AnyRoute], to: [AnyRoute])
    case presented(Presentation)
    case dismissed(FlowID)
    case tabSelected(from: String, to: String)
}
```

### Rules the state always keeps

The router checks these in one place, so the state can never break them:

- A tab container's selection is one of its tabs.
- Dismissing a presentation removes its whole subtree.
- A flow presents at most one child flow at a time.

A command that would break a rule is refused with a `NavigationIssue` and leaves the state unchanged. See <doc:StackNavigation> for outcomes and fallbacks.
