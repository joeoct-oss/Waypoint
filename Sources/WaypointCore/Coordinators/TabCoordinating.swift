//
//  TabCoordinating.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Code that owns a tab container and a stack coordinator for each tab, without their screens.
///
/// Apps write `TabCoordinator` from the `Waypoint` product, which refines this protocol. Code
/// with no UI, such as tests on Linux, conforms to this one. Conforming fills in the router: it
/// is made with ``makeRouter()`` the first time it is read, and each tab's coordinator is asked
/// for then, so each tab's stack is its coordinator's router from the start.
///
/// ```swift
/// final class MainCoordinator: TabCoordinating {
///     func makeRouter() -> TabRouter<MainTab> {
///         TabRouter(tabs: MainTab.allCases, selection: .shop)
///     }
///
///     func coordinator(for tab: MainTab) -> any StackCoordinating {
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
/// Each tab's coordinator is asked for once, and kept as long as this coordinator and its tab
/// are. A tab added later is asked for when it is added, and a removed tab's coordinator is let
/// go. Return a different coordinator for each tab, a new one or one this coordinator keeps: one
/// returned for two tabs is reported as `coordinatorDrawnTwice`, and the second tab keeps a stack
/// of its own, or shows the tabs' shared stack. A kept coordinator returned again for a tab added
/// back gets the tab's new stack.
///
/// With ``TabStacks/shared``, the selected tab's coordinator is asked first, and its router
/// becomes the shared stack. Every other tab's coordinator drives that same stack: a router it
/// made on its own sends its calls to the shared stack, and screens it pushed or presented on
/// that router before joining are dropped and reported as `tabChildRouterMerged`.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router, and the
///   router table knows it by its identity.
@MainActor
public protocol TabCoordinating: AnyObject {
    /// The app's tab type, usually an enum.
    associatedtype Tab: NavigationTab

    /// The router of the tab container. Default: made with ``makeRouter()`` the first time it
    /// is read, and kept until the coordinator is gone.
    var router: TabRouter<Tab> { get }

    /// Makes the router, the first time ``router`` is read. No default, because only the app
    /// knows its tabs and which one is selected first.
    func makeRouter() -> TabRouter<Tab>

    /// The stack coordinator of `tab`. Asked once per tab, when the router is made or the tab is
    /// added.
    func coordinator(for tab: Tab) -> any StackCoordinating
}

extension TabCoordinating {
    /// The router from the router table, made on the first read.
    public var router: TabRouter<Tab> {
        RouterTable.shared.router(of: self)
    }

    /// A navigator for the screen on top of `tab`'s stack, taking any route. Hand it to that
    /// screen's view model instead of the router.
    ///
    /// Taking it checks the coordinator's router: a stored one is reported as
    /// `routerNotFromWaypoint`, adopted, and its tabs get their children.
    ///
    /// - Parameters:
    ///   - tab: The tab whose stack the navigator drives.
    ///   - file: The file of the call, where an issue is reported. Leave the default.
    ///   - line: The line of the call, where an issue is reported. Leave the default.
    public func navigator(for tab: Tab, file: StaticString = #fileID, line: UInt = #line) -> StackNavigator {
        RouterTable.shared.checkedRouter(of: self, file: file, line: line).router(for: tab).navigator
    }
}
