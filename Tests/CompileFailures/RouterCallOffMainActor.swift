//
//  RouterCallOffMainActor.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must not compile: routers change navigation on the main actor only (planning #278, P1).
// expected-error: call to main actor-isolated instance method 'push(_:trigger:else:file:line:)' in a synchronous nonisolated context
// swift-5: fails

import WaypointCore

// Conformances:
// - `Route`, so it can be pushed.
struct ReceiptRoute: Route { }

nonisolated func showReceipt(on router: StackRouter) {
    router.push(ReceiptRoute())
}
