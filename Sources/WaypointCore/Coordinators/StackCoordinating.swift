//
//  StackCoordinating.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Code that owns one stack flow, without its screens.
///
/// Apps write `StackCoordinator` from the `Waypoint` product, which refines this protocol and
/// adds the screens. Code with no UI, such as tests on Linux, conforms to this one. Conforming
/// fills in the router: it is made the first time it is read, named after the coordinator, given
/// the coordinator's destinations, and released once the coordinator is gone.
///
/// ```swift
/// final class ShopCoordinator: StackCoordinating {
///     func showProduct(_ id: Int) {
///         router.push(ProductRoute(id: id))
///     }
/// }
/// ```
///
/// Don't store a router. A coordinator that wants a router of its own, such as one with the
/// app's ``NavigationConfiguration``, implements ``makeRouter()``. A stored `let router` goes
/// around Waypoint: the first time Waypoint touches the coordinator it reports
/// `routerNotFromWaypoint` and adopts the router, and a push made before then can fail with
/// `unregisteredRoute`. Don't read the router in `deinit` either: a coordinator going away gets
/// an inert router whose calls return `.ignored`.
///
/// Conformances:
/// - `AnyObject`, because a coordinator is one shared object that owns its router, and the
///   router table knows it by its identity.
@MainActor
public protocol StackCoordinating: AnyObject {
    /// The router of this coordinator's stack. Default: made with ``makeRouter()`` the first
    /// time it is read, and kept until the coordinator is gone.
    var router: StackRouter { get }

    /// The name of the stack's root screen in the journey, when the root screen has no route.
    /// Default: the type's name without `Coordinator`, such as `Shop` for `ShopCoordinator`.
    /// It replaces a root name the router came with, so name the root here, not in
    /// ``makeRouter()``.
    var rootName: String { get }

    /// Makes the router, the first time ``router`` is read. Default: `StackRouter()`.
    ///
    /// ```swift
    /// func makeRouter() -> StackRouter {
    ///     StackRouter(flow: FlowID("shop"), configuration: navigation)
    /// }
    /// ```
    func makeRouter() -> StackRouter

    /// Registers the route types this coordinator's screens show, once per router, as soon as
    /// the router is made. Default: registers nothing. Later in #59, `StackCoordinator`
    /// registers its `destinations`.
    func registerDestinations(on router: StackRouter)
}

extension StackCoordinating {
    /// The router from the router table, made on the first read.
    public var router: StackRouter {
        RouterTable.shared.router(of: self)
    }

    /// The type's name without `Coordinator`.
    public var rootName: String {
        RouterTable.typeRootName(of: Self.self)
    }

    /// A navigator for the screen on top of the stack, taking any route. Hand it to that
    /// screen's view model instead of the router.
    ///
    /// Taking it checks the coordinator's router: a stored one is reported as
    /// `routerNotFromWaypoint` and adopted.
    public var navigator: StackNavigator {
        RouterTable.shared.checkedRouter(of: self, file: #fileID, line: #line).navigator
    }

    /// A new router with the default settings.
    public func makeRouter() -> StackRouter {
        StackRouter()
    }

    /// Registers nothing.
    public func registerDestinations(on router: StackRouter) { }

    /// A navigator for the screen on top of the stack that takes only the routes of `flow`.
    ///
    /// ```swift
    /// let model = ProductModel(navigation: navigator(for: ShopFlow.self))
    /// ```
    ///
    /// Taking it checks the coordinator's router, as ``navigator`` does.
    ///
    /// - Parameters:
    ///   - flow: The flow whose routes the navigator takes.
    ///   - file: The file of the call, where an issue is reported. Leave the default.
    ///   - line: The line of the call, where an issue is reported. Leave the default.
    public func navigator<Flow: NavigationFlow>(
        for flow: Flow.Type,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> FlowNavigator<Flow> {
        RouterTable.shared
            .checkedRouter(of: self, file: file, line: line)
            .navigator(for: flow, file: file, line: line)
    }
}
