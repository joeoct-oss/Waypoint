//
//  RouterStoredInSendableType.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must compile: a router is a main-actor type, so a `Sendable` value may keep it (#24).

import WaypointCore

// Conformances:
// - `Sendable`, so it can be handed to any task.
struct Session: Sendable {
    let router: StackRouter
}

@MainActor
func makeSession() -> Session {
    Session(router: StackRouter())
}
