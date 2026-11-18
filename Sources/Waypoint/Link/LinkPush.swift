//
//  LinkPush.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: what a link does on a tap uses only the core, so its rules
// are unit tested on Linux too. The SwiftUI view is in `WaypointLink.swift`.

import WaypointCore

/// What a ``WaypointLink`` does when tapped: push its route through the router of the nearest
/// stack, like any other push.
///
/// Conformances:
/// - `R: Route`: the route type the link pushes.
struct LinkPush<R: Route> {
    /// The route to push, or `nil` for a link that pushes nothing, like a system link whose value
    /// is `nil`.
    let route: R?

    /// The fallback for this push when it fails, or `nil` for the router's own.
    let fallback: NavigationFallback?

    /// The file that made the link, named in logs and issues.
    let file: StaticString

    /// The line that made the link, named in logs and issues.
    let line: UInt

    /// A push of `route` that names the given call site in logs and issues.
    init(
        route: R?,
        fallback: NavigationFallback?,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        self.route = route
        self.fallback = fallback
        self.file = file
        self.line = line
    }

    /// Whether a tap can push: the link has a route and is inside a stack.
    @MainActor
    func isEnabled(on router: StackRouter?) -> Bool {
        route != nil && router != nil
    }

    /// Pushes the route onto `router` and returns the push's outcome, or `nil` when the link is
    /// disabled.
    @MainActor
    @discardableResult
    func run(on router: StackRouter?) -> NavigationOutcome? {
        guard let route, let router else {
            return nil
        }
        return router.push(
            route,
            else: fallback,
            file: file,
            line: line
        )
    }
}
