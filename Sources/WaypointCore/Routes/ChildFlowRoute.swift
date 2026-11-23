//
//  ChildFlowRoute.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The place on a parent's path where a pushed child flow starts: the child's root screen. The
/// child's own screens follow it on screen, and popping it ends the flow.
///
/// Waypoint pushes it, never an app. A renderer draws the child's root screen for it.
///
/// Conformances:
/// - `Route`, so it sits on the parent's path like any other screen.
package struct ChildFlowRoute: Route {
    /// The name of the pushed child's flow.
    package let flow: String

    /// The flow name is no user data.
    package static var publicLogFields: Set<String> {
        let fields: Set<String> = ["flow"]
        return fields
    }

    /// The marker for the child flow named `flow`.
    package init(flow: String) {
        self.flow = flow
    }
}
