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
/// Waypoint pushes it, never an app. A renderer draws the child's root screen for it. Each push
/// gets a marker of its own, also when the same flow is pushed again after it ended, so a
/// renderer never takes a new flow's marker for an old one's screen.
///
/// Conformances:
/// - `Route`, so it sits on the parent's path like any other screen.
package struct ChildFlowRoute: Route {
    /// The name of the pushed child's flow.
    package let flow: String

    /// The number of the push in its tree, which tells two pushes of one flow apart.
    package let pushID: UInt64

    /// The flow name is no user data.
    package static var publicLogFields: Set<String> {
        let fields: Set<String> = ["flow", "pushID"]
        return fields
    }

    /// The marker for the push numbered `pushID` of the child flow named `flow`.
    package init(flow: String, pushID: UInt64) {
        self.flow = flow
        self.pushID = pushID
    }
}
