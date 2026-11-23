//
//  TabCoordinator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// App code that owns a tab container and a stack coordinator for each tab.
///
/// Conforming fills in the router, as `TabCoordinating` describes: made with `makeRouter()` the
/// first time it is read, with each tab's coordinator asked for then, so `router.router(for:)`
/// returns that coordinator's router from the start. Until the coordinator draws its own `view`
/// (#13), draw it with a SwiftUI `TabView` bound to `router.selection`, with
/// `WaypointStack(router.router(for: tab))` in each tab.
///
/// ```swift
/// final class MainCoordinator: TabCoordinator {
///     func makeRouter() -> TabRouter<MainTab> {
///         TabRouter(tabs: MainTab.allCases, selection: .shop)
///     }
///
///     func tabCoordinator(for tab: MainTab) -> any StackCoordinator {
///         switch tab {
///         case .shop:
///             ShopCoordinator()
///         case .cart:
///             CartCoordinator()
///         }
///     }
/// }
/// ```
///
/// Conformances:
/// - `TabCoordinating`, the core protocol with the router and its defaults, which has no UI so
///   a coordinator's logic is tested on Linux.
@MainActor
public protocol TabCoordinator: TabCoordinating {
    /// The stack coordinator of `tab`. Asked once per tab, when the router is made or the tab is
    /// added. Return a different coordinator for each tab: a new one, or one this coordinator
    /// keeps, which gets a new stack when its tab is removed and added back.
    func tabCoordinator(for tab: Tab) -> any StackCoordinator
}

extension TabCoordinator {
    /// The tab's stack coordinator, from ``tabCoordinator(for:)``.
    public func coordinator(for tab: Tab) -> any StackCoordinating {
        tabCoordinator(for: tab)
    }
}
