//
//  ProductScreen.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// A screen a products stack can push.
//
// Conformances:
// - `Hashable`, so `NavigationStack` can keep screens in its path and tell them apart.
enum ProductScreen: Hashable {
    case product(Product)
}

// Where a products stack starts: browsing the shop, or searching it.
enum ProductsStart {
    case browse
    case search
}

// A sheet a products stack can present: the filters over the shop, or the wish list over a product.
//
// Conformances:
// - `Identifiable`, so `.sheet(item:)` shows one sheet at a time and swaps them cleanly.
enum ProductSheet: Identifiable {
    case filters
    case wishlist

    var id: Self {
        self
    }
}
