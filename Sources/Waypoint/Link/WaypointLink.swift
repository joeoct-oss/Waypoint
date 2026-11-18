//
//  WaypointLink.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// A view that pushes a route onto the nearest ``WaypointStack`` when tapped.
    ///
    /// Use it where you would write `NavigationLink(value:)`. Its initializers take the same
    /// arguments, so moving an existing view onto Waypoint is a rename:
    ///
    /// ```swift
    /// // Before
    /// NavigationLink(value: ProductRoute(id: product.id)) {
    ///     ProductRow(product: product)
    /// }
    ///
    /// // After
    /// WaypointLink(value: ProductRoute(id: product.id)) {
    ///     ProductRow(product: product)
    /// }
    /// ```
    ///
    /// A tap calls `push` on the stack's router, so the push is checked, logged and saved like
    /// any other: a route type with no destination is refused, a second tap while the screen
    /// still slides in pushes nothing, and a failed push runs its fallback. Pass `else:` to choose
    /// the fallback for this link.
    ///
    /// A system `NavigationLink(value:)` inside a Waypoint stack pushes a value the router can't
    /// read back, so the push is refused and reported as `rendererMismatch` at `.error`, in debug
    /// and release builds alike.
    ///
    /// The link is disabled when its value is `nil`, like a system link, and outside a Waypoint
    /// stack, where there is no router to push onto. It draws as a `Button`, so `.buttonStyle(_:)`
    /// styles it; unlike a system link, it shows no disclosure chevron in a `List`.
    ///
    /// Conformances:
    /// - `Label: View`: what the link shows.
    /// - `R: Route`: the route type the link pushes.
    public struct WaypointLink<Label: View, R: Route>: View {
        /// What a tap does.
        private let push: LinkPush<R>

        /// What the link shows.
        private let label: Label

        /// The router of the nearest stack, or `nil` outside one.
        @Environment(\.waypointStackRouter) private var router

        /// A button that pushes the route, disabled when there is nothing to push or nowhere to
        /// push it.
        public var body: some View {
            Button {
                push.run(on: router)
            } label: {
                label
            }
            .disabled(!push.isEnabled(on: router))
        }

        /// Creates a link that pushes `value` and shows `label`.
        ///
        /// - Parameters:
        ///   - value: The route to push, or `nil` for a disabled link.
        ///   - fallback: What to do when the push fails. Default: `nil`, the router's own
        ///     fallback.
        ///   - file: The file named in logs and issues. Default: the caller's.
        ///   - line: The line named in logs and issues. Default: the caller's.
        ///   - label: What the link shows.
        public init(
            value: R?,
            else fallback: NavigationFallback? = nil,
            file: StaticString = #fileID,
            line: UInt = #line,
            @ViewBuilder label: () -> Label
        ) {
            self.push = LinkPush(
                route: value,
                fallback: fallback,
                file: file,
                line: line
            )
            self.label = label()
        }
    }

    extension WaypointLink where Label == Text {
        /// Creates a link that pushes `value` and shows a localized title.
        ///
        /// - Parameters:
        ///   - titleKey: The key of the title to show.
        ///   - value: The route to push, or `nil` for a disabled link.
        ///   - fallback: What to do when the push fails. Default: `nil`, the router's own
        ///     fallback.
        ///   - file: The file named in logs and issues. Default: the caller's.
        ///   - line: The line named in logs and issues. Default: the caller's.
        public init(
            _ titleKey: LocalizedStringKey,
            value: R?,
            else fallback: NavigationFallback? = nil,
            file: StaticString = #fileID,
            line: UInt = #line
        ) {
            self.init(
                value: value,
                else: fallback,
                file: file,
                line: line
            ) {
                Text(titleKey)
            }
        }

        /// Creates a link that pushes `value` and shows a title as it is, without localizing it.
        ///
        /// - Parameters:
        ///   - title: The title to show.
        ///   - value: The route to push, or `nil` for a disabled link.
        ///   - fallback: What to do when the push fails. Default: `nil`, the router's own
        ///     fallback.
        ///   - file: The file named in logs and issues. Default: the caller's.
        ///   - line: The line named in logs and issues. Default: the caller's.
        ///
        /// Conformances:
        /// - `S: StringProtocol`: any kind of string, as a system link takes.
        @_disfavoredOverload
        public init<S: StringProtocol>(
            _ title: S,
            value: R?,
            else fallback: NavigationFallback? = nil,
            file: StaticString = #fileID,
            line: UInt = #line
        ) {
            self.init(
                value: value,
                else: fallback,
                file: file,
                line: line
            ) {
                Text(title)
            }
        }
    }
#endif
