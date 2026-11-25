//
//  ProductCatalog.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The products the shop sells. The app's catalog is `SampleCatalog`, the fixed sample products; a
// test passes a catalog of its own, so a screen can be tried with other products.
package protocol ProductCatalog {
    // Every product, in the order the shop lists them.
    var products: [Product] { get }

    // The product with this id, or `nil` when the catalog has none.
    func product(id: Int) -> Product?
}

extension ProductCatalog {
    // The products with these ids, in the same order, leaving out ids the catalog has none for.
    package func products(withIDs ids: [Int]) -> [Product] {
        ids.compactMap { product(id: $0) }
    }
}

// The fixed sample products, `Product.all`.
//
// Conformances:
// - `ProductCatalog`, so the app hands it to every feature that lists products.
package struct SampleCatalog: ProductCatalog {
    package init() { }

    package var products: [Product] {
        Product.all
    }

    package func product(id: Int) -> Product? {
        Product.find(id: id)
    }
}
