//
//  ScreenBuilder.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    #if canImport(UIKit)
        import UIKit
    #endif

    /// Builds one screen of a coordinator, its `root` or a destination's screen, from a SwiftUI
    /// view or, where UIKit is, a view controller. `if`, `if let` and `switch` work as in
    /// `@ViewBuilder`.
    ///
    /// ```swift
    /// var root: some View {
    ///     ProductListView(onSelect: { self.showProduct(id: $0) })
    /// }
    /// ```
    @MainActor
    @resultBuilder
    public enum ScreenBuilder {
        /// A SwiftUI view, as it is.
        public static func buildBlock<Content: View>(_ content: Content) -> Content {
            content
        }

        /// An empty screen, for a branch that shows nothing.
        public static func buildBlock() -> EmptyView {
            EmptyView()
        }

        /// A screen shown only when an `if` holds.
        public static func buildOptional<Content: View>(_ content: Content?) -> Content? {
            content
        }

        /// The first branch of an `if` or `switch`.
        public static func buildEither<First: View, Second: View>(
            first content: First
        ) -> EitherScreen<First, Second> {
            EitherScreen.first(content)
        }

        /// The second branch of an `if` or `switch`.
        public static func buildEither<First: View, Second: View>(
            second content: Second
        ) -> EitherScreen<First, Second> {
            EitherScreen.second(content)
        }

        /// A SwiftUI view, as it is.
        public static func buildExpression<Content: View>(_ content: Content) -> Content {
            content
        }

        #if canImport(UIKit)
            /// A view controller, shown through a representable.
            public static func buildExpression<Controller: UIViewController>(
                _ controller: Controller
            ) -> ControllerScreen<Controller> {
                ControllerScreen(controller: controller)
            }
        #endif
    }

    /// One of two screens, from an `if` or a `switch` in a ``ScreenBuilder``.
    ///
    /// Conformances:
    /// - `View`, so the chosen screen is drawn.
    /// - `First: View` and `Second: View`: the two screens it chooses between.
    public enum EitherScreen<First: View, Second: View>: View {
        /// The first branch.
        case first(First)
        /// The second branch.
        case second(Second)

        /// The chosen screen.
        public var body: some View {
            switch self {
            case .first(let content):
                content
            case .second(let content):
                content
            }
        }
    }

    #if canImport(UIKit)
        /// A view controller as a coordinator's screen.
        ///
        /// Conformances:
        /// - `UIViewControllerRepresentable`, so SwiftUI shows the controller.
        /// - `Controller: UIViewController`: the controller it shows.
        public struct ControllerScreen<Controller: UIViewController>: UIViewControllerRepresentable {
            /// The controller it shows, made once by the coordinator.
            let controller: Controller

            /// The controller, as it was made.
            public func makeUIViewController(context: Context) -> Controller {
                controller
            }

            /// Nothing to update: the controller keeps its own state.
            public func updateUIViewController(_ controller: Controller, context: Context) { }
        }
    #endif
#endif
