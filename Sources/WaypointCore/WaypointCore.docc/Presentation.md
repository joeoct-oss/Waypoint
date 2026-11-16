# Presentation

Show a flow as a sheet or a full-screen cover, and choose its sizes.

## Overview

Any router can present one child flow at a time. The child flow gets its own router, so it can push, present again and dismiss itself.

```swift
router.present(FilterRoute(), style: .sheet)
router.dismiss()
```

A sheet is large by default. Choose other sizes when you need them:

```swift
router.present(FilterRoute(), style: .sheet(detents: [.medium, .large]))
```

Presenting a coordinator's flow, and getting a result back when it ends, is covered in the coordinators article.

### Presenting and dismissing

These methods are on `StackRouter` and `TabRouter`. Like every navigation method, they return a `NavigationOutcome` and take an optional fallback, file and line, left out here.

```swift
extension StackRouter {
    /// Presents `route` as the root screen of a new child flow.
    ///
    /// If a flow is already presented, returns `.failed` with
    /// `alreadyPresenting` unless a fallback says otherwise.
    @discardableResult
    public func present<R: Route>(_ route: R, style: PresentationStyle = .sheet) -> NavigationOutcome

    /// The router of the presented flow, if any.
    public var presented: StackRouter? { get }

    /// Dismisses the flow this router presents.
    ///
    /// Returns `.alreadyThere` when nothing is presented.
    @discardableResult public func dismiss() -> NavigationOutcome

    /// Dismisses every flow presented above this router.
    @discardableResult public func dismissAll() -> NavigationOutcome

    /// Asks whoever presented this router's flow to dismiss it.
    @discardableResult public func dismissFlow() -> NavigationOutcome

    /// Default presentation options for this router and its children.
    public var presentationDefaults: PresentationDefaults { get set }
}
```

### Styles

```swift
/// How a flow is presented.
public struct PresentationStyle: Hashable, Codable, Sendable {
    /// A sheet that uses the router's default sheet options. Large unless changed.
    public static var sheet: PresentationStyle { get }

    /// A sheet with the given options.
    public static func sheet(_ options: SheetOptions) -> PresentationStyle

    /// A sheet with the given sizes. The first size is selected.
    public static func sheet(detents: [SheetDetent], selected: SheetDetent? = nil) -> PresentationStyle

    /// A full-screen cover.
    public static var fullScreenCover: PresentationStyle { get }
}
```

### Sheet sizes

Sheet sizes are plain values in the navigation state. That means a restored or deep linked sheet comes back at the same size, and tests can check it on Linux. The SwiftUI and UIKit renderers turn them into the platform's own sheet sizes.

```swift
/// One size a sheet can rest at.
public enum SheetDetent: Hashable, Codable, Sendable {
    case medium
    case large
    /// A fraction of the available height, from 0 to 1.
    case fraction(Double)
    /// A fixed height in points.
    case height(Double)
    /// A size the app defines, resolved by a rule registered with the renderer.
    case custom(String)
}

/// Options for a sheet.
public struct SheetOptions: Hashable, Codable, Sendable {
    public init(
        detents: [SheetDetent] = [.large],
        selectedDetent: SheetDetent? = nil,
        showsDragIndicator: Bool? = nil,
        allowsInteractiveDismiss: Bool = true
    )

    /// The sizes the sheet can rest at. Default: `[.large]`.
    public var detents: [SheetDetent]
    /// The size the sheet opens at. `nil` means the first detent.
    public var selectedDetent: SheetDetent?
    /// `nil` lets the platform decide.
    public var showsDragIndicator: Bool?
    /// Whether the user can swipe the sheet away. Default: `true`.
    public var allowsInteractiveDismiss: Bool

    /// A large sheet that the user can swipe away.
    public static var `default`: SheetOptions { get }
}
```

When the user drags a sheet to another size, the renderer reports it and `selectedDetent` changes, as with any other change the user makes. A size the platform cannot show falls back to `.large`, and an issue is reported in development.

### Defaults you can change

Nothing is fixed. Set a default once for a flow or the whole app, and a single call can still choose its own options.

```swift
/// Default options for presentations from a router and its children.
public struct PresentationDefaults: Sendable {
    /// Used by `.sheet` when a call doesn't pass its own options.
    public var sheet: SheetOptions
}

rootRouter.presentationDefaults.sheet = SheetOptions(detents: [.medium, .large])
```

The lookup order is: the call's own options, then the nearest router's `presentationDefaults`, then `SheetOptions.default`.
