//
//  ProductCollection.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// A themed set of products that Shop shows as a banner. Fixed sample data, like the products.
//
// Conformances:
// - `Hashable`, so a collection can be compared and kept in a route's hint.
// - `Identifiable`, so a route can name a collection by its id.
nonisolated struct ProductCollection: Hashable, Identifiable {
    static let nebulaNights = ProductCollection(
        id: "nebula-nights",
        name: "Nebula nights",
        tagline: "Throws and prints, from $32",
        productIDs: nebulaNightsProducts
    )
    static let all = [
        nebulaNights,
    ]

    private static let nebulaNightsProducts = [
        3,
        4,
    ]

    let id: String
    let name: String
    let tagline: String
    let productIDs: [Int]

    var products: [Product] {
        Product.products(withIDs: productIDs)
    }

    static func find(id: String) -> ProductCollection? {
        all.first { $0.id == id }
    }
}
