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
///
/// Conformances:
/// - `Hashable`, so presentations can be compared.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct PresentationStyle: Hashable, Codable, Sendable, NavigationDescribable {
    /// A sheet that uses the router's default sheet options. Large unless changed.
    public static var sheet: PresentationStyle { get }

    /// A sheet with the given options.
    public static func sheet(_ options: SheetOptions) -> PresentationStyle

    /// A sheet with the given sizes. The first size is selected.
    public static func sheet(detents: [SheetDetent], selected: SheetDetent? = nil) -> PresentationStyle

    /// A full-screen cover.
    public static var fullScreenCover: PresentationStyle { get }

    /// The sheet's own options, or `nil` for a `.sheet` that uses the
    /// router's defaults and for a full-screen cover.
    public var sheetOptions: SheetOptions? { get }

    /// Whether this is a full-screen cover.
    public var isFullScreenCover: Bool { get }
}
```

### Sheet sizes

Sheet sizes are plain values in the navigation state. That means a restored or deep linked sheet comes back at the same size, and tests can check it on Linux. The SwiftUI and UIKit renderers turn them into the platform's own sheet sizes.

```swift
/// One size a sheet can rest at.
///
/// Conformances:
/// - `Hashable`, so detents can be compared and kept in sets.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `CustomStringConvertible`, so presentation styles print their sizes as `[medium, large]`.
public enum SheetDetent: Hashable, Codable, Sendable, CustomStringConvertible {
    /// About half the available height.
    case medium
    /// The full available height.
    case large
    /// A fraction of the available height, from 0 to 1.
    case fraction(Double)
    /// A fixed height in points.
    case height(Double)
    /// As tall as the sheet's content, up to `SheetOptions.fitsContentLimit`.
    case fitsContent
    /// A size the app defines, resolved by a rule registered with the renderer.
    case custom(String)
}

/// Options for a sheet.
///
/// Conformances:
/// - `Hashable`, so presentations can be compared.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
public struct SheetOptions: Hashable, Codable, Sendable {
    /// Creates sheet options. Every argument has a default.
    public init(
        detents: [SheetDetent] = [.large],
        selectedDetent: SheetDetent? = nil,
        fitsContentLimit: SheetDetent = .large,
        showsDragIndicator: Bool? = nil,
        allowsInteractiveDismiss: Bool = true
    )

    /// The sizes the sheet can rest at. Default: `[.large]`.
    public var detents: [SheetDetent]
    /// The size the sheet opens at. `nil` means the first detent.
    public var selectedDetent: SheetDetent?
    /// The tallest a `.fitsContent` sheet can grow. Taller content scrolls. Default: `.large`.
    public var fitsContentLimit: SheetDetent
    /// `nil` lets the platform decide.
    public var showsDragIndicator: Bool?
    /// Whether the user can swipe the sheet away. Default: `true`.
    public var allowsInteractiveDismiss: Bool

    /// A large sheet that the user can swipe away.
    public static var `default`: SheetOptions { get }
}
```

When the user drags a sheet to another size, the renderer reports it and `selectedDetent` changes, as with any other change the user makes. A size the platform cannot show falls back to `.large`, and an issue is reported in development.

### Sheets that fit their content

Use `.fitsContent` for a sheet that should be exactly as tall as what it shows, such as a confirmation or a short picker:

```swift
router.present(ShareRoute(item: item.id), style: .sheet(detents: [.fitsContent]))
```

- The state stores `.fitsContent`, not a number. The renderer measures the content, so a restored sheet fits the device, text size and language it opens with.
- When the content's height changes, the sheet animates to the new height. That isn't a navigation change, so no event is sent.
- A sheet never grows past `fitsContentLimit`, `.large` by default. Taller content stops there and scrolls: the renderer puts it in a scroll view, unless a UIKit screen's root view already scrolls.
- Mix it with other sizes: `[.fitsContent, .large]` opens at the content's height and lets the user pull the sheet up.
- The content needs a natural height. A view that fills whatever space it gets, such as a `List`, has none. Waypoint reports `fitsContentHasNoHeight` in development and uses the limit.
- On iPad in regular width, a sheet is a form sheet, sized to the content where the platform allows it.

```swift
let options = SheetOptions(detents: [.fitsContent], fitsContentLimit: .fraction(0.6))
router.present(FilterRoute(), style: .sheet(options))
```

### Defaults you can change

Nothing is fixed. Set a default once for a flow or the whole app, and a single call can still choose its own options.

```swift
/// Default options for presentations from a router and its children.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct PresentationDefaults: Sendable {
    /// Used by `.sheet` when a call doesn't pass its own options.
    public var sheet: SheetOptions
}

rootRouter.presentationDefaults.sheet = SheetOptions(detents: [.medium, .large])
```

The lookup order is: the call's own options, then the nearest router's `presentationDefaults`, then `SheetOptions.default`.
