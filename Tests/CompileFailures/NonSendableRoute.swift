//
//  NonSendableRoute.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must not compile: a route must be safe to send to any thread (#24, P2).
// expected-error: stored property 'cart' of 'Sendable'-conforming struct 'CartRoute' has non-Sendable type 'Cart'
// swift-5: warns

import WaypointCore

// A mutable model, not safe to share between threads.
//
// Conformances:
// - `Hashable` and `Codable`, as a route's fields must be.
final class Cart: Hashable, Codable {
    var itemCount = 0

    static func == (lhs: Cart, rhs: Cart) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

// Conformances:
// - `Route`, which requires `Sendable`.
struct CartRoute: Route {
    let cart: Cart
}
