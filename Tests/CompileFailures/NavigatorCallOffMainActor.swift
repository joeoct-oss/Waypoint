//
//  NavigatorCallOffMainActor.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must not compile: a navigator used from background work must hop to the main actor
// (planning #278, P1).
// expected-error: main actor-isolated instance method 'push(_:trigger:else:file:line:)' cannot be called from outside of the actor
// swift-5: fails

import WaypointCore

// Conformances:
// - `Route`, so it can be pushed.
struct ReceiptRoute: Route { }

@MainActor
func showReceiptLater(with navigation: StackNavigator) {
    Task.detached {
        navigation.push(ReceiptRoute())
    }
}
