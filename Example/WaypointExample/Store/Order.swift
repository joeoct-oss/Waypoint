//
//  Order.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// A past order, shown in Account. Fixed sample data, like the products.
//
// Conformances:
// - `Hashable`, so an order can sit in a navigation path.
// - `Identifiable`, so lists can show orders without naming an id key path.
struct Order: Hashable, Identifiable {
    static let all = [
        Order(id: 1042, productName: "Orbit Lamp", status: "Delivered"),
        Order(id: 1057, productName: "Comet Mug", status: "On its way"),
    ]

    let id: Int
    let productName: String
    let status: String
}
