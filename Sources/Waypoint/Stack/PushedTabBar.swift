//
//  PushedTabBar.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI

    /// How the tab bar leaves when a screen that hides it is pushed, and comes back when it is
    /// popped.
    ///
    /// Conformances:
    /// - `Sendable`, so it can sit in the environment.
    /// - `Hashable`, so the stack can compare the app's choice.
    public enum PushedTabBarMotion: Sendable, Hashable {
        /// The pushed screen slides in on top of the tab bar, and the bar leaves with the screen
        /// underneath, as `hidesBottomBarWhenPushed` does in UIKit. A pop and a swipe back bring
        /// it back the same way. The default.
        case slidesWithScreen

        /// SwiftUI's own `.toolbar(_:for: .tabBar)`: the bar disappears at the start of a push
        /// and appears once a pop ends.
        case system
    }

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
        /// With `.hidden`, the tab bar is never hidden on its own: each pushed screen slides in
        /// on top of it and the bar leaves with the screen underneath, as in UIKit
        /// (``PushedTabBarMotion/slidesWithScreen``). Pass ``PushedTabBarMotion/system`` for
        /// SwiftUI's own `.toolbar(_:for: .tabBar)` instead. When the stack can't reach the
        /// controller UIKit pushes, it falls back to SwiftUI's own way, so the bar is still
        /// hidden. `.visible` always uses SwiftUI's way, and every pushed screen of the stack gets
        /// the same visibility, whatever a screen sets inside itself. The tab bar only exists on
        /// iOS, so other systems ignore it.
        ///
        /// - Parameters:
        ///   - visibility: The tab bar's visibility on every pushed screen.
        ///   - motion: How the bar leaves and comes back when it is hidden. Default:
        ///     ``PushedTabBarMotion/slidesWithScreen``.
        public func tabBarOnPushedScreens(
            _ visibility: Visibility,
            motion: PushedTabBarMotion = .slidesWithScreen
        ) -> some View {
            environment(\.waypointPushedTabBar, PushedTabBar(visibility: visibility, motion: motion))
        }
    }

    /// The app's choice for the tab bar on pushed screens.
    ///
    /// Conformances:
    /// - `Sendable`, so it can sit in the environment.
    struct PushedTabBar: Sendable {
        /// The tab bar's visibility on every pushed screen.
        let visibility: Visibility

        /// How the bar leaves and comes back when it is hidden.
        let motion: PushedTabBarMotion

        /// Whether the stack slides the bar away with the screen, through UIKit.
        var slidesWithScreen: Bool {
            visibility == .hidden && motion == .slidesWithScreen
        }
    }

    /// Applies the tab bar visibility the app chose for pushed screens to one pushed screen. It
    /// sends nothing for `.automatic`, so the system decides.
    ///
    /// Conformances:
    /// - `ViewModifier`, so every pushed screen of a stack gets it the same way.
    struct PushedTabBarModifier: ViewModifier {
        /// What the app chose with ``SwiftUICore/View/tabBarOnPushedScreens(_:motion:)``.
        @Environment(\.waypointPushedTabBar) private var choice

        /// Whether the bridge couldn't reach the pushed controller, so SwiftUI hides the bar.
        @State private var bridgeFailed = false

        /// The screen, with the chosen tab bar visibility.
        @ViewBuilder
        func body(content: Content) -> some View {
            #if os(iOS)
                if choice.visibility == .automatic {
                    content
                } else if choice.slidesWithScreen, !bridgeFailed {
                    content.background {
                        PushedTabBarBridge(onFailure: { bridgeFailed = true })
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                } else {
                    content.toolbar(choice.visibility, for: .tabBar)
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
        /// The tab bar on pushed screens, chosen with
        /// ``SwiftUICore/View/tabBarOnPushedScreens(_:motion:)``. Default: `.automatic`.
        @Entry var waypointPushedTabBar = PushedTabBar(visibility: .automatic, motion: .slidesWithScreen)
    }
#endif
