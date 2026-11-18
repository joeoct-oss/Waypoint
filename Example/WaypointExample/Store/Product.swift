//
//  Product.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// A product in the shop. The example app's data is local and fixed, so every journey can be tested
// without a network.
//
// Conformances:
// - `Hashable`, so a product can sit in a navigation path and tell itself apart from the others.
// - `Identifiable`, so lists can show products without naming an id key path.
struct Product: Hashable, Identifiable {
    static let all = [
        Product(
            id: 1,
            name: "Orbit Lamp",
            price: 89,
            symbolName: "lamp.desk",
            summary: "A warm desk lamp with a ring that glows."
        ),
        Product(
            id: 2,
            name: "Comet Mug",
            price: 18,
            symbolName: "mug",
            summary: "A stoneware mug that keeps coffee hot."
        ),
        Product(
            id: 3,
            name: "Nebula Throw",
            price: 64,
            symbolName: "square.stack",
            summary: "A soft blanket in deep blues."
        ),
        Product(
            id: 4,
            name: "Lunar Clock",
            price: 42,
            symbolName: "clock",
            summary: "A silent wall clock with a moon face."
        ),
        Product(
            id: 5,
            name: "Star Chart Print",
            price: 35,
            symbolName: "sparkles",
            summary: "A print of the night sky in spring."
        ),
        Product(
            id: 6,
            name: "Rocket Bookends",
            price: 29,
            symbolName: "books.vertical",
            summary: "Two brass bookends for a full shelf."
        ),
    ]

    static func products(withIDs ids: [Int]) -> [Product] {
        ids.compactMap(product(withID:))
    }

    static func product(withID id: Int) -> Product? {
        all.first { $0.id == id }
    }

    static func total(of products: [Product]) -> Decimal {
        products.reduce(0) { $0 + $1.price }
    }

    let id: Int
    let name: String
    let price: Decimal
    let symbolName: String
    let summary: String
}
