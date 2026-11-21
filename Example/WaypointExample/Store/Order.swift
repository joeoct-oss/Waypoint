//
//  Order.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// A past order, shown in Account: its number, what was in it, a status line and how far it has
// come. Fixed sample data, like the products.
//
// Conformances:
// - `Hashable`, so an order can sit in a navigation path.
// - `Codable`, so an order can sit in an account route, which Waypoint can save and restore.
// - `Identifiable`, so lists can show orders without naming an id key path.
struct Order: Hashable, Codable, Identifiable {
    static let all = [
        Order(
            id: 1042,
            productIDs: lampAndMug,
            statusLine: "Shipped · arrives tomorrow",
            stage: .shipped
        ),
        Order(
            id: 1031,
            productIDs: mug,
            statusLine: "Delivered Nov 2",
            stage: .delivered
        ),
        Order(
            id: 1007,
            productIDs: throwBlanket,
            statusLine: "Delivered Oct 12",
            stage: .delivered
        ),
    ]

    private static let lampAndMug = [
        1,
        2,
    ]
    private static let mug = [
        2,
    ]
    private static let throwBlanket = [
        3,
    ]

    // How many orders are still on their way, for Account's Orders row.
    static var onTheirWayCount: Int {
        all.filter { $0.stage != .delivered }.count
    }

    let id: Int
    let productIDs: [Int]
    let statusLine: String
    let stage: OrderStage

    var products: [Product] {
        Product.products(withIDs: productIDs)
    }

    var total: Decimal {
        Product.total(of: products)
    }
}

// How far an order has come, in the order an order's timeline shows the stages.
//
// Conformances:
// - `CaseIterable`, so the timeline lists every stage from this one declaration.
// - `Comparable`, so the timeline can tell a stage the order has reached from one it hasn't.
// - `Codable` (from the raw values), so an order with its stage can sit in an account route.
enum OrderStage: Int, CaseIterable, Comparable, Codable {
    case placed
    case shipped
    case delivered

    var title: String {
        switch self {
        case .placed:
            return "Placed"
        case .shipped:
            return "Shipped"
        case .delivered:
            return "Delivered"
        }
    }

    static func < (lhs: OrderStage, rhs: OrderStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
