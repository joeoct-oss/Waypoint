//
//  PushedTabBar.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI

    extension View {
        /// Chooses whether the tab bar shows on the screens pushed onto the stacks inside this
        /// view, as `hidesBottomBarWhenPushed` does in UIKit. A stack's first screen is never
        /// changed, so a tab's root keeps the system's tab bar.
        ///
        /// Without it, pushed screens keep the system's behaviour (`.automatic`): the tab bar
        /// stays, as Apple's guidelines suggest. Put it on the stack, or on any view above the
        /// stacks it should change:
        ///
        /// ```swift
        /// WaypointStack(router) {
        ///     ProductListView()
        ///         .destination(ProductRoute.self) { route in
        ///             ProductView(id: route.id)
        ///         }
        /// }
        /// .tabBarOnPushedScreens(.hidden)
        /// ```
        ///
        /// The stack applies `visibility` around each pushed screen with
        /// `.toolbar(_:for: .tabBar)`, so a screen can still choose for itself with its own
        /// `.toolbar(_:for: .tabBar)`, which SwiftUI applies over the stack's. The tab bar only
        /// exists on iOS, so other systems ignore it.
        ///
        /// - Parameter visibility: The tab bar's visibility on every pushed screen.
        public func tabBarOnPushedScreens(_ visibility: Visibility) -> some View {
            environment(\.waypointPushedTabBar, visibility)
        }
    }

    /// Applies the tab bar visibility the app chose for pushed screens to one pushed screen. It
    /// sends nothing for `.automatic`, so the system decides.
    ///
    /// Conformances:
    /// - `ViewModifier`, so every pushed screen of a stack gets it the same way.
    struct PushedTabBarModifier: ViewModifier {
        /// What the app chose with ``SwiftUICore/View/tabBarOnPushedScreens(_:)``.
        @Environment(\.waypointPushedTabBar) private var visibility

        /// The screen, with the chosen tab bar visibility.
        @ViewBuilder
        func body(content: Content) -> some View {
            #if os(iOS)
                if visibility == .automatic {
                    content
                } else {
                    content.toolbar(visibility, for: .tabBar)
                }
            #else
                content
            #endif
        }
    }

    extension View {
        /// This pushed screen, with the tab bar visibility the app chose for pushed screens.
        func pushedTabBar() -> some View {
            modifier(PushedTabBarModifier())
        }
    }

    extension EnvironmentValues {
        /// The tab bar visibility on pushed screens, chosen with
        /// ``SwiftUICore/View/tabBarOnPushedScreens(_:)``. Default: `.automatic`.
        @Entry var waypointPushedTabBar: Visibility = .automatic
    }
#endif
