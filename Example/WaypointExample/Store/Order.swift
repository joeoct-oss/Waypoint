//
//  Order.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// A past order, shown in Account. Fixed sample data, like the products.
//
// Conformances:
// - `Hashable`, so an order can sit in a navigation path.
// - `Codable`, so an order can sit in an account route, which Waypoint can save and restore.
// - `Identifiable`, so lists can show orders without naming an id key path.
struct Order: Hashable, Codable, Identifiable {
    static let all = [
        Order(id: 1042, productName: "Orbit Lamp", status: "Delivered"),
        Order(id: 1057, productName: "Comet Mug", status: "On its way"),
    ]

    let id: Int
    let productName: String
    let status: String
}
