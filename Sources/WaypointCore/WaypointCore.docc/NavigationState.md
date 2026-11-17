# Navigation state

Navigation is a tree of plain values that routers own and renderers draw.

## Overview

Everything on screen is described by value types: a stack's path, what it presents, which tab is selected. They are `Sendable`, `Equatable` and `Codable`, so you can compare them in tests, log them, save them and rebuild them.

Routers own the state and are the only way to change it. Renderers read it and report changes the user makes, such as a swipe back, but never keep their own copy.

```swift
let router = StackRouter()
router.push(ProductRoute(id: 42))

router.state.path        // [ProductRoute(id: 42)]
router.state.presentation // nil
```

### Stacks

```swift
/// The state of one navigation stack.
public struct StackState: Sendable, Equatable, Codable {
    /// The routes pushed above the stack's root screen, bottom first.
    ///
    /// The root screen belongs to the stack itself, not the path, as in
    /// `NavigationStack(path:)`. An empty path shows the root screen.
    public var path: [AnyRoute]

    /// The flow this stack presents, if any.
    public var presentation: Presentation?
}
```

### Presentations

A flow presents at most one child flow at a time. The presented flow can present again, which gives a chain of modals, as in both SwiftUI and UIKit. See <doc:Presentation> for styles and sheet sizes.

```swift
/// A child flow shown modally above its parent.
public struct Presentation: Sendable, Equatable, Codable {
    /// How the flow is shown.
    public var style: PresentationStyle

    /// The presented flow.
    public var flow: FlowID
}
```

### Tabs

```swift
/// The state of a tab container.
///
/// `Tab` is usually an app enum, such as a `MainTab` with `home`, `shop` and `profile` cases.
public struct TabState<Tab: Hashable & Codable & Sendable>: Sendable, Equatable, Codable {
    /// The tabs, in display order.
    public var tabs: [Tab]

    /// The selected tab. Always one of `tabs`.
    public var selection: Tab

    /// The flow presented above the whole tab container, if any.
    public var presentation: Presentation?
}
```

### The whole tree

Each router has a stable `FlowID`. The erased form of the whole app's state is a `NavigationTree`, which is what snapshots, deep link plans and debug output use.

```swift
/// A stable name for one flow in the tree.
///
/// Stays the same across restoration, so events and snapshots can refer to it.
public struct FlowID: Hashable, Codable, Sendable, CustomStringConvertible {
    public init(_ name: String)
    public var description: String { get }
}

/// The erased navigation state of every flow, from the root down.
public struct NavigationTree: Sendable, Equatable, Codable {
    public enum Node: Sendable, Equatable, Codable {
        case stack(FlowID, StackState)
        case tabs(FlowID, selection: String, tabs: [String: NavigationTree])
        case root(FlowID, current: String, child: NavigationTree?)
    }
    public var root: Node
    public var presented: [FlowID: NavigationTree]
}
```

### Changes

Every applied change is described by a value. Routers emit them as events, and tests can compare them.

```swift
/// One change to the navigation state.
public enum NavigationChange: Sendable, Equatable {
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
