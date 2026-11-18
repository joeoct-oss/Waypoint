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
            category: "Lighting",
            price: 48,
            artwork: .orbitLamp,
            summary: "A warm desk lamp with a ring that glows along an orbit."
        ),
        Product(
            id: 2,
            name: "Comet Mug",
            category: "Kitchen",
            price: 18,
            artwork: .cometMug,
            summary: "A stoneware mug that keeps coffee hot."
        ),
        Product(
            id: 3,
            name: "Nebula Throw",
            category: "Home",
            price: 64,
            artwork: .nebulaThrow,
            summary: "A soft blanket in deep blues and pinks."
        ),
        Product(
            id: 4,
            name: "Star Chart Print",
            category: "Wall art",
            price: 32,
            artwork: .starChartPrint,
            summary: "A framed print of the night sky in spring."
        ),
        Product(
            id: 5,
            name: "Pole Star Candle",
            category: "Home",
            price: 22,
            artwork: .poleStarCandle,
            summary: "A slow candle in a jar with a gold star."
        ),
        Product(
            id: 6,
            name: "Pole Star Lamp",
            category: "Lighting",
            price: 56,
            artwork: .poleStarLamp,
            summary: "A green reading lamp that points its light down."
        ),
    ]

    static func products(withIDs ids: [Int]) -> [Product] {
        ids.compactMap(find(id:))
    }

    static func find(id: Int) -> Product? {
        all.first { $0.id == id }
    }

    static func total(of products: [Product]) -> Decimal {
        products.reduce(0) { $0 + $1.price }
    }

    let id: Int
    let name: String
    let category: String
    let price: Decimal
    let artwork: ProductArtwork
    let summary: String

    // The next product in the shop, after the last one the first, shown on a product's page as
    // something the reader might also like.
    var related: Product {
        let index = Self.all.firstIndex(of: self) ?? 0
        return Self.all[(index + 1) % Self.all.count]
    }
}
