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
package nonisolated struct ProductCollection: Hashable, Identifiable {
    package static let nebulaNights = ProductCollection(
        id: "nebula-nights",
        name: "Nebula nights",
        tagline: "Throws and prints, from $32",
        productIDs: nebulaNightsProducts
    )
    package static let all = [
        nebulaNights
    ]

    private static let nebulaNightsProducts = [
        3,
        4,
    ]

    package let id: String
    package let name: String
    package let tagline: String
    package let productIDs: [Int]

    package var products: [Product] {
        Product.products(withIDs: productIDs)
    }

    package static func find(id: String) -> ProductCollection? {
        all.first { $0.id == id }
    }
}
