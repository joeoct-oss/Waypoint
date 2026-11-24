//
//  RouterStateReadOffMainActor.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must not compile: a router's state is read on the main actor only (planning #278, P1).
// expected-error: main actor-isolated property 'state' can not be referenced from a nonisolated context
// swift-5: fails

import WaypointCore

nonisolated func currentPath(of router: StackRouter) -> [AnyRoute] {
    router.state.path
}
