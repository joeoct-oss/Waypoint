# Tabs

Keep one stack per tab, and switch tabs from code or a deep link.

## Overview

`TabRouter` owns a tab container. Each tab has its own child router, so every tab keeps its own stack when the user switches away and back.

```swift
// Conformances:
// - `String` raw value: gives each case a readable name in logs and saved state.
// - `Hashable`, required by `TabRouter`, which selects and compares tabs.
// - `Codable`, required by `TabRouter`, which saves and restores the selection with the tree.
// - `Sendable`, required by `TabRouter`, so events that name the tab can leave the main actor.
enum MainTab: String, Hashable, Codable, Sendable {
    case home
    case shop
    case profile
}

let tabs = TabRouter(tabs: [.home, .shop, .profile], selection: .home)
tabs.select(.shop)
tabs.router(for: .shop).push(ProductRoute(id: 42))
```

Tab types need `Hashable`, `Codable` and `Sendable`. See <doc:WhyTheseConformances>.

When the user taps a tab, the renderer reports it, and the selection changes like any other change, with `origin: .user`.

### The tab router

Navigation methods return a `NavigationOutcome` and take an optional fallback, file and line, left out here.

```swift
/// The owner of a tab container.
///
/// `Tab` is usually an app enum. Its raw value or `Codable` form is what
/// snapshots and logs show.
///
/// Conformances:
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
@MainActor @Observable
public final class TabRouter<Tab: Hashable & Codable & Sendable> {
    /// Creates a tab container. `selection` should be one of `tabs`; if it
    /// isn't, the first tab is selected. `flow` names the container.
    public init(tabs: [Tab], selection: Tab, flow: FlowID = FlowID("tabs"))

    /// The current state. Change it only through the methods below.
    public private(set) var state: TabState<Tab>

    /// The selected tab.
    public var selection: Tab { get }

    /// Selects a tab.
    ///
    /// Returns `.alreadyThere` if it is selected, and `.failed` with
    /// `unknownTab` if it is not one of `tabs` and no fallback applies.
    @discardableResult public func select(_ tab: Tab) -> NavigationOutcome

    /// The stack router of one tab. Its flow is named after the tab. A tab
    /// that isn't one of `tabs` gets a router outside the tree, whose calls
    /// return `.ignored`.
    public func router(for tab: Tab) -> StackRouter

    /// Replaces the list of tabs.
    ///
    /// If the selected tab is removed, the first tab is selected and the
    /// removed tab's stack is released.
    @discardableResult public func setTabs(_ tabs: [Tab]) -> NavigationOutcome

    // Presenting above the whole tab container: `present`, `dismiss`,
    // `dismissAll` and `presentationDefaults`, as on StackRouter.

    /// The flow this router drives.
    public var flowID: FlowID { get }
    /// What to do when a call fails. Inherited by every tab's router.
    public var fallbackPolicy: FallbackPolicy { get set }
}
```

### Changing tabs and stacks together

A deep link often selects a tab, closes a sheet and sets the tab's path. Do it in one transaction, so the renderer draws once:

```swift
tabs.transaction {
    $0.dismissAll()
    $0.select(.shop)
    $0.router(for: .shop).setPath {
        ProductListRoute(category: "all")
        ProductRoute(id: 42)
    }
}
```

### Tapping the selected tab again

Tapping the tab that is already selected pops its stack to the root, as system apps do. It is on by default, and you can turn it off:

```swift
extension TabRouter {
    /// Whether tapping the selected tab pops its stack to the root. Default: `true`.
    public var popsToRootOnReselect: Bool { get set }
}
```
