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
            + "uses it from now on, but calls made before now could fail with unregisteredRoute. "
            + "Remove the stored router, and implement makeRouter() to make one of your own."
        let issue = NavigationIssue(kind: .routerNotFromWaypoint, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .error)
    }

    /// Reports `routerOwnedByAnotherCoordinator`: `coordinator` stores this router, which `owner`
    /// owns. Waypoint leaves it as it is: not adopted, renamed or registered on.
    func reportRouterOwned(by owner: AnyObject, storedIn coordinator: AnyObject, file: StaticString, line: UInt) {
        let name = ViewTypeName.of(type(of: coordinator))
        let ownerName = ViewTypeName.of(type(of: owner))
        let message = "\(name) stores the router of \(ownerName), so both drive one stack. Waypoint "
            + "leaves it with \(ownerName). Give \(name) a router of its own: remove the stored "
            + "router, or implement makeRouter()."
        let issue = NavigationIssue(
            kind: .routerOwnedByAnotherCoordinator,
            flow: flowID,
            message: message,
            file: file,
            line: line
        )
        tree.report(issue, level: .error)
    }
}
