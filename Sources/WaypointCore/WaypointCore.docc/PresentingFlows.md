# Presentation

Show a flow as a sheet or a full-screen cover, and choose its sizes.

## Overview

Any router can present one child flow at a time. The child flow gets its own router, so it can push, present again and dismiss itself.

```swift
router.present(FilterRoute(), style: .sheet)
router.dismiss()
```

A presented flow is named after its route, such as `settings` for `SettingsRoute`, with `-2`, `-3` added when the name is taken. A sheet is large by default. Choose other sizes when you need them:

```swift
let detents: [SheetDetent] = [.medium, .large]
router.present(FilterRoute(), style: .sheet(detents: detents))
```

Presenting a coordinator's flow, and getting a result back when it ends, is covered in <doc:CoordinatorsAndChildFlows>. A destination can also declare how its route is shown, so the call site writes only `router.show(_:)`: see "Declared presentation" below.

### Presenting and dismissing

These methods are on `StackRouter` and `TabRouter`. Like every navigation method, they return a `NavigationOutcome` and take an optional fallback, file and line, left out here.

```swift
extension StackRouter {
    /// The router of the presented flow, if any.
    public var presented: StackRouter? { get }
    /// Default presentation options for this router and its children.
    public var presentationDefaults: PresentationDefaults { get }

    /// Sets the default presentation options for this router and its children.
    public func setPresentationDefaults(_ defaults: PresentationDefaults)

    /// Presents `route` as the root screen of a new child flow.
    ///
    /// If a flow is already presented, returns `.failed` with
    /// `alreadyPresenting` unless a fallback says otherwise, such as
    /// `.replacePresentation`.
    @discardableResult
    public func present<R: Route>(
        _ route: R,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
    /// Dismisses the flow this router presents.
    ///
    /// Returns `.alreadyThere` when nothing is presented.
    @discardableResult public func dismiss(
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// Dismisses every flow presented above this router.
    @discardableResult public func dismissAll(
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome

    /// Asks whoever presented this router's flow to dismiss it.
    @discardableResult public func dismissFlow(
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
    /// The sheet options a presentation uses: its own, or this router's defaults.
    public func sheetOptions(for presentation: Presentation) -> SheetOptions
}
```

> Note: Two kinds of presentation are coming. Alerts and confirmation dialogs become presentations in the navigation state, shown by both renderers, with the tapped button returned as a typed result. And when something Waypoint didn't present is on screen, such as a share sheet or a payment sheet from another SDK, Waypoint will wait until it closes before presenting, or dismiss it first if the app chooses, and report it in the log. Tracked in #154 and #153.

> Note: Two more changes are coming. A popover style anchored to a view, which becomes a sheet in compact width (#156). And a leave confirmation set at run time with `router.setLeaveConfirmation(_:)`, which asks before swipe back, a sheet drag or Back, next to the fixed `allowsInteractiveDismiss` below (#155).

### Declared presentation

> Note: Draft until #12. `show(_:)` and the `presentation:` parameter are planned, not built, and can still change when #12 lands.

A route that is always shown the same way can say so once, next to its screen, instead of at every call site. Its destination declares a default presentation, and `show(_:)` uses it:

```swift
private static let filterDetents: [SheetDetent] = [.medium, .large]

var destinations: some Destinations {
    Destination(ProductRoute.self) { route in
        ProductView(id: route.id)
    }
    Destination(FilterRoute.self, presentation: .sheet(detents: Self.filterDetents)) { _ in
        FilterView()
    }
}
```

```swift
router.show(FilterRoute())                         // the destination's default: a sheet
router.present(FilterRoute(), style: .sheet)       // the call's own choice still wins
router.push(FilterRoute())                         // and so does an explicit push
```

- **Order:** the call's explicit verb, then the destination's declared presentation, then a push. A destination with no `presentation:` is pushed.
- The same parameter is on `.destination(_:presentation:_:)` for a `WaypointStack` with no coordinator, and on a coordinator's `Flow(...)` entry (see <doc:CoordinatorsAndChildFlows>).
- A declared `.sheet` with no options takes the router's sheet defaults, as `present(_:style: .sheet)` does.
- The default belongs to the router whose coordinator or stack declared it. Two coordinators can show the same route differently, and a pushed child flow's `show` reads its own declarations.
- Routes stay plain values: a route never carries its presentation, so links and restored state hold no UI choices.

Everything after `show` picks a verb is the same as calling that verb. The state, the log and restoration record the style it chose, so the log reads "sheet", never "show". A route with no destination takes the missing-destination path, and a second presentation follows the rules below, such as `.replacePresentation`.

```swift
extension StackRouter {
    /// Pushes or presents `route` as its destination declares, or pushes it
    /// when the destination declares nothing.
    @discardableResult
    public func show<R: Route>(
        _ route: R,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil
    ) -> NavigationOutcome
}
```

### Replacing what is presented

A flow presents one flow at a time. When newer intent should win, such as a notification tap while a sheet is open, pass `.replacePresentation`: it dismisses the presented flow and everything above it, then presents the new route with the call's style, in one change.

```swift
func showOrder(id: Order.ID) {
    router.present(OrderRoute(id: id), else: .replacePresentation)
}
```

The outcome is `.recovered(alreadyPresenting, by: .replacePresentation)` when something was replaced, and `.applied` when nothing was presented. If the new route can't be presented, the dismissal is rolled back too. A replacement made in code doesn't ask the presented flow for a leave confirmation; that applies only to the user's own gestures (#155). To replace across the app, set it once as the router's fallback for `alreadyPresenting`:

```swift
router.setFallback(.replacePresentation, for: .alreadyPresenting)
```

### Styles

```swift
/// How a flow is presented.
///
/// Conformances:
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events
///   and test failures.
public struct PresentationStyle: NavigationValue, NavigationDescribable {
    /// A sheet that uses the router's default sheet options. Large unless changed.
    public static var sheet: PresentationStyle { get }
    /// A full-screen cover.
    public static var fullScreenCover: PresentationStyle { get }

    /// The sheet's own options, or `nil` for a `.sheet` that uses the
    /// router's defaults and for a full-screen cover.
    public var sheetOptions: SheetOptions? { get }

    /// Whether this is a full-screen cover.
    public var isFullScreenCover: Bool { get }

    /// A sheet with the given options.
    public static func sheet(_ options: SheetOptions) -> PresentationStyle

    /// A sheet with the given sizes. The first size is selected.
    public static func sheet(
        detents: [SheetDetent],
        selected: SheetDetent? = nil
    ) -> PresentationStyle
}
```

### Sheet sizes

Sheet sizes are plain values in the navigation state. That means a restored or deep linked sheet comes back at the same size, and tests can check it on Linux. The SwiftUI and UIKit renderers turn them into the platform's own sheet sizes.

```swift
/// One size a sheet can rest at.
///
/// Conformances:
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
/// - `CustomStringConvertible`, so presentation styles print their sizes as `[medium, large]`.
public enum SheetDetent: NavigationValue, CustomStringConvertible {
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
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
public struct SheetOptions: NavigationValue {
    /// A large sheet that the user can swipe away.
    public static var `default`: SheetOptions { get }

    /// The sizes the sheet can rest at, never empty. Default: `[.large]`.
    public let detents: [SheetDetent]
    /// The size the sheet opens at, always one of `detents`. `nil` means the first detent.
    public let selectedDetent: SheetDetent?
    /// The tallest a `.fitsContent` sheet can grow. Taller content scrolls. Default: `.large`.
    public let fitsContentLimit: SheetDetent
    /// `nil` lets the platform decide.
    public let showsDragIndicator: Bool?
    /// Whether the user can swipe the sheet away. Default: `true`.
    public let allowsInteractiveDismiss: Bool

    /// Creates sheet options. Every argument has a default.
    public init(
        detents: [SheetDetent] = [.large],
        selectedDetent: SheetDetent? = nil,
        fitsContentLimit: SheetDetent = .large,
        showsDragIndicator: Bool? = nil,
        allowsInteractiveDismiss: Bool = true
    )

    /// The same options with other sizes, checked like `init`.
    public func withDetents(_ detents: [SheetDetent], selected: SheetDetent? = nil) -> SheetOptions
    /// The same options with another limit for `.fitsContent` sheets.
    public func withFitsContentLimit(_ limit: SheetDetent) -> SheetOptions
    /// The same options with the drag indicator shown, hidden, or left to the platform.
    public func withDragIndicator(_ shows: Bool?) -> SheetOptions
    /// The same options, with swiping the sheet away allowed or not.
    public func withInteractiveDismiss(_ allowed: Bool) -> SheetOptions
}
```

Sheet options are always valid, so a renderer never meets one it can't show: an empty `detents` becomes `[.large]`, a `selectedDetent` that isn't one of `detents` becomes `nil`, and a `fitsContentLimit` of `.fitsContent`, which is not a limit, becomes `.large`. Decoded options are checked the same way.

When the user drags a sheet to another size, the renderer reports it and `selectedDetent` changes, as with any other change the user makes. A size the platform cannot show falls back to `.large`, and an issue is reported in development.

### Sheets that fit their content

Use `.fitsContent` for a sheet that should be exactly as tall as what it shows, such as a confirmation or a short picker:

```swift
let detents: [SheetDetent] = [.fitsContent]
router.present(ShareRoute(item: item.id), style: .sheet(detents: detents))
```

- The state stores `.fitsContent`, not a number. The renderer measures the content, so a restored sheet fits the device, text size and language it opens with.
- When the content's height changes, the sheet animates to the new height. That isn't a navigation change, so no event is sent.
- A sheet never grows past `fitsContentLimit`, `.large` by default. Taller content stops there and scrolls: the renderer puts it in a scroll view, unless a UIKit screen's root view already scrolls.
- Mix it with other sizes: `[.fitsContent, .large]` opens at the content's height and lets the user pull the sheet up.
- The content needs a natural height. A view that fills whatever space it gets, such as a `List`, has none. Waypoint reports `fitsContentHasNoHeight` in development and uses the limit.
- On iPad in regular width, a sheet is a form sheet, sized to the content where the platform allows it.

```swift
let detents: [SheetDetent] = [.fitsContent]
let options = SheetOptions(detents: detents, fitsContentLimit: .fraction(0.6))
router.present(FilterRoute(), style: .sheet(options))
```

### Defaults you can change

Nothing is fixed. Set a default once for a flow or the whole app, and a single call can still choose its own options.

```swift
/// Default options for presentations from a router and its children.
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
/// - `Equatable`, so tests can compare defaults.
public struct PresentationDefaults: Sendable, Equatable {
    /// Large sheets that the user can swipe away.
    public static var `default`: PresentationDefaults { get }

    /// Used by `.sheet` when a call doesn't pass its own options.
    public let sheet: SheetOptions

    /// Creates defaults. Every argument has a default.
    public init(sheet: SheetOptions = .default)

    /// The same defaults with other sheet options.
    public func withSheet(_ sheet: SheetOptions) -> PresentationDefaults
}

let detents: [SheetDetent] = [.medium, .large]
let sheet = SheetOptions(detents: detents)
rootRouter.setPresentationDefaults(PresentationDefaults(sheet: sheet))
```

The lookup order is: the call's own options, then the nearest router's `presentationDefaults`, then `SheetOptions.default`.
