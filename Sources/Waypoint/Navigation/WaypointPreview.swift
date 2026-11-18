//
//  WaypointPreview.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    extension View {
        /// Shows the view in a stack with a fresh router whose registry is permissive, so the
        /// navigation wrappers work in a preview and pushes need no registered destination.
        ///
        /// ```swift
        /// #Preview {
        ///     HelpView()
        ///         .waypointPreview()
        /// }
        /// ```
        public func waypointPreview() -> some View {
            modifier(PreviewStackModifier(flow: nil))
        }

        /// Shows the view in a stack of `flow` with a fresh, permissive router, so
        /// `@FlowNavigation(flow)` works in a preview.
        ///
        /// ```swift
        /// #Preview {
        ///     ProductView(id: 1)
        ///         .waypointPreview(flow: ShopFlow.self)
        /// }
        /// ```
        public func waypointPreview<Flow: NavigationFlow>(flow: Flow.Type) -> some View {
            modifier(PreviewStackModifier(flow: flow))
        }
    }

    /// Puts a view in a preview stack with its own permissive router.
    ///
    /// Conformances:
    /// - `ViewModifier`, so ``SwiftUICore/View/waypointPreview()`` can apply it.
    struct PreviewStackModifier: ViewModifier {
        /// The flow the preview stack is declared for, or `nil`.
        let flow: (any NavigationFlow.Type)?

        /// The preview's router. Made once for the preview's lifetime.
        @State private var router = StackRouter(configuration: .permissive)

        /// The view inside a stack.
        func body(content: Content) -> some View {
            WaypointStack(router: router, flow: flow) {
                content
            }
        }
    }
#endif
