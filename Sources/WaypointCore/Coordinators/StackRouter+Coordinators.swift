//
//  StackRouter+Coordinators.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension StackRouter {
    /// A router whose calls return `.ignored` and log `staleNavigator`, for a coordinator going
    /// away whose own router is still in use.
    static func inert() -> StackRouter {
        let router = StackRouter()
        router.markDetached()
        return router
    }

    /// Reports `routerNotFromWaypoint`: `coordinator` stores this router instead of taking the
    /// one Waypoint makes. Waypoint adopts it from now on.
    func reportRouterNotFromWaypoint(storedIn coordinator: AnyObject, file: StaticString, line: UInt) {
        let name = ViewTypeName.of(type(of: coordinator))
        let message = "\(name) stores its router instead of taking the one Waypoint makes. Waypoint "
            + "uses it from now on, but calls made before now could fail with unregisteredRoute, and "
            + "its root screen is now named by rootName. Remove the stored router, implement "
            + "makeRouter() to make one of your own, and name the root with rootName."
        let issue = NavigationIssue(
            kind: .routerNotFromWaypoint,
            flow: flowID,
            message: message,
            file: file,
            line: line
        )
        tree.report(issue, level: .error)
    }

    /// Reports `releasedRouterReturned`: `coordinator` got this router from its `makeRouter()`
    /// or stores it, but the router ended with the coordinator it belonged to, so its calls
    /// return `.ignored`.
    func reportReleasedRouterReturned(
        to coordinator: AnyObject,
        from source: RouterTable.Source,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: coordinator))
        let how = source == .made ? "\(name).makeRouter() returned" : "\(name) stores"
        let message = "\(how) a router whose coordinator is gone. A router ends with its "
            + "coordinator, so this one ignores every call. Give each coordinator a new router: "
            + "make one in makeRouter() each time it is called."
        let issue = NavigationIssue(
            kind: .releasedRouterReturned,
            flow: flowID,
            message: message,
            file: file,
            line: line
        )
        tree.report(issue, level: .error)
    }

    /// Reports `rootNameReplaced`: the root name `makeRouter()` gave this router, `earlier`, is
    /// replaced by the coordinator's `rootName`.
    func reportRootNameReplaced(
        _ earlier: String,
        by rootName: String,
        of coordinator: AnyObject,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: coordinator))
        let message = "\(name).makeRouter() named the root screen \"\(earlier)\", and \(name).rootName "
            + "names it \"\(rootName)\" instead. Name the root screen with rootName, not in makeRouter()."
        let issue = NavigationIssue(kind: .rootNameReplaced, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .error)
    }

    /// Reports `routerOwnedByAnotherCoordinator`: `coordinator` stores this router, or its
    /// `makeRouter()` returns it, and `owner` owns it. Waypoint leaves it as it is: not adopted,
    /// renamed or registered on, so the coordinator's own routes stay unregistered.
    func reportRouterOwned(
        by owner: AnyObject,
        heldBy coordinator: AnyObject,
        from source: RouterTable.Source,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: coordinator))
        let ownerName = ViewTypeName.of(type(of: owner))
        let how = source == .made ? "makeRouter() returns" : "stores"
        let fix = source == .made
            ? "make a new router in makeRouter()"
            : "remove the stored router, or implement makeRouter()"
        let text = "\(name) \(how) the router of \(ownerName), so both drive one stack. Waypoint "
            + "leaves it with \(ownerName) and registers none of \(name)'s destinations on it. Give "
            + "\(name) a router of its own: \(fix)."
        let issue = NavigationIssue(
            kind: .routerOwnedByAnotherCoordinator,
            flow: flowID,
            message: text,
            file: file,
            line: line
        )
        tree.report(issue, level: .error)
    }
}
