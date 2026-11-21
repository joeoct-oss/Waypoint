# Tabs

Keep one stack per tab or one stack above the tabs, and switch tabs from code or a deep link.

## Overview

`TabRouter` owns a tab container. By default each tab has its own child router, so every tab keeps its own stack when the user switches away and back. With `stacks: .shared`, the tabs share one stack above the tab bar instead (see [One stack above the tabs](#One-stack-above-the-tabs)).

> Note: Draft until #59. In a tab coordinator, each tab's stack coordinator has its own router, and `router(for:)` returns that same router. See "Joining the tree" in <doc:CoordinatorsAndChildFlows>.

```swift
// Conformances:
// - `String` raw value: gives each case a readable name in logs and saved state.
// - `NavigationTab`, so `TabRouter` can select and compare tabs, save and restore the selection,
//   and name tabs in events off the main actor.
// - `CaseIterable`, so `TabRouter` shows every tab without a list.
enum MainTab: String, NavigationTab, CaseIterable {
    case home
    case shop
    case profile
}

let tabs = TabRouter(selection: MainTab.home)
tabs.select(.shop)
tabs.router(for: .shop).push(ProductRoute(id: 42))
```

Tab types conform to `NavigationTab`, which is `Hashable`, `Codable` and `Sendable` under one name. See <doc:WhyTheseConformances>.

### Choosing the tabs

A `CaseIterable` tab type shows every case, in the order the cases are declared. To show only some of them, or in another order, such as a tab that only signed-in users see, pass `tabs`:

```swift
let guestTabs: [MainTab] = [.home, .shop]
let tabs = TabRouter(tabs: guestTabs, selection: .home)
```

A tab type that isn't `CaseIterable` always passes `tabs`.

When the user taps a tab, the renderer reports it, and the selection changes like any other change, with `origin: .user`.

### The tab router

Navigation methods return a `NavigationOutcome` and take an optional fallback, file and line, left out here.

```swift
/// A tab of a tab container, usually an app enum.
///
/// Conformances:
/// - `NavigationValue`, so tabs can be selected and compared, the selection is saved and
///   restored, and tabs are named in events off the main actor.
public protocol NavigationTab: NavigationValue { }

/// The owner of a tab container.
///
/// `Tab` is usually an app enum. Its raw value or `Codable` form is what
/// snapshots and logs show.
///
/// Conformances:
/// - `Tab: NavigationTab`, the app's tab type.
@MainActor @Observable
public final class TabRouter<Tab: NavigationTab> {
    /// Whether tapping the selected tab pops its stack to the root. Default: `true`.
    public let popsToRootOnReselect: Bool

    /// The current state. Change it only through the methods below.
    public var state: TabState<Tab> { get }

    /// The selected tab.
    public var selection: Tab { get }
    /// The flow this router drives.
    public var flowID: FlowID { get }
    /// What to do when a call fails. Inherited by every tab's router.
    public var fallbackPolicy: FallbackPolicy { get }
    /// What a push of the route still being pushed does. Inherited by every
    /// tab's router.
    public var duplicatePushRule: DuplicatePushRule { get }

    /// Creates a tab container. `selection` should be one of `tabs`; if it
    /// isn't, the first tab is selected. `flow` names the container.
    public init(
        tabs: [Tab],
        selection: Tab,
        flow: FlowID = FlowID("tabs"),
        stacks: TabStacks = .perTab,
        popsToRootOnReselect: Bool = true
    )

    /// Creates a tab container with every case of a `CaseIterable` tab type,
    /// in the order the cases are declared.
    public convenience init(
        selection: Tab,
        flow: FlowID = FlowID("tabs"),
        stacks: TabStacks = .perTab,
        popsToRootOnReselect: Bool = true
    ) where Tab: CaseIterable

    /// Sets the duplicate push rule for this container and everything inside it.
    public func setDuplicatePushRule(_ rule: DuplicatePushRule)

    /// Sets one kind's fallback for this container and everything inside it.
    public func setFallback(
        _ fallback: NavigationFallback?,
        for kind: NavigationIssue.Kind,
        file: StaticString = #fileID,
        line: UInt = #line
    )

    /// Selects a tab.
    ///
    /// Returns `.alreadyThere` if it is selected, and `.failed` with
    /// `unknownTab` if it is not one of `tabs` and no fallback applies.
    @discardableResult public func select(
        _ tab: Tab,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// The stack router of one tab. Its flow is named after the tab. With
    /// `stacks: .shared` it is the same router, named `stack`, for every
    /// tab. A tab that isn't one of `tabs` gets a router outside the tree,
    /// whose calls return `.ignored`.
    public func router(for tab: Tab) -> StackRouter

    /// Replaces the list of tabs.
    ///
    /// If the selected tab is removed, the first tab is selected and the
    /// removed tab's stack is released.
    @discardableResult public func setTabs(
        _ tabs: [Tab],
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    // Presenting above the whole tab container: `present`, `dismiss`,
    // `dismissAll` and `presentationDefaults`, as on StackRouter.
}
```

### One stack above the tabs

With one stack per tab, the tab bar stays under every pushed screen unless the stack hides it, and SwiftUI then hides and shows it without moving it. To have pushed screens slide in over the tab bar, as system apps that put the stack around the tabs do, share one stack above the tabs:

```swift
/// Where a tab container's pushed screens go.
public enum TabStacks: Sendable, Hashable {
    /// Each tab has its own stack and keeps it. The default.
    case perTab
    /// The tabs share one stack above the tab bar.
    case shared
}
```

```swift
let tabs = TabRouter(selection: MainTab.home, stacks: .shared)
tabs.router(for: .shop).push(ProductRoute(id: 42))   // the shared stack
```

With `.shared`:
- `router(for:)` returns the same router for every tab, so a tab's coordinator pushes as it would with its own stack.
- Selecting another tab pops the pushed screens in the same change, so no pushed screen stays over a tab the user can't see. Leaving a tab loses its pushed screens.
- A transaction that selects a tab and then sets the path keeps that path.
- The tree shows the shared stack once, as `stack`.

The renderer draws the shared stack around the tab bar, as the SwiftUI renderer article in the `Waypoint` documentation shows.

### Changing tabs and stacks together

A deep link often selects a tab, closes a sheet and sets the tab's path. Do it in one transaction, so the renderer draws once:

```swift
tabs.transaction {
    $0.dismissAll()
    $0.select(MainTab.shop)
    $0.router(for: MainTab.shop).setPath {
        ProductListRoute(category: "all")
        ProductRoute(id: 42)
    }
}
```

### Tapping the selected tab again

Tapping the tab that is already selected pops its stack to the root, as system apps do. It is on by default, and you can turn it off when you create the container:

```swift
let tabs = TabRouter(selection: MainTab.home, popsToRootOnReselect: false)
```
