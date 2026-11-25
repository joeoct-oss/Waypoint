//
//  ProductsCart.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// What a products stack knows of the cart: its products, for Shop's "Your cart is waiting" card and
// the cart pushed above a product, and the three choices it reports to the main tabs, Add to cart,
// Go to cart and Check out. The cart itself belongs to the Cart tab.
struct ProductsCart {
    let products: () -> [Product]
    let onAddToCart: (Product) -> Void
    let onGoToCart: () -> Void
    let onCheckout: () -> Void
}
