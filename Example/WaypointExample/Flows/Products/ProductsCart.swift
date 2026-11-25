//
//  ProductsCart.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleStore

// What a products stack knows of the cart: its products, for Shop's "Your cart is waiting" card and
// the cart pushed above a product, and the three choices it reports to the main tabs, Add to cart,
// Go to cart and Check out. The cart itself belongs to the Cart tab.
package struct ProductsCart {
    package let products: () -> [Product]
    package let onAddToCart: (Product) -> Void
    package let onGoToCart: () -> Void
    package let onCheckout: () -> Void

    package init(
        products: @escaping () -> [Product],
        onAddToCart: @escaping (Product) -> Void,
        onGoToCart: @escaping () -> Void,
        onCheckout: @escaping () -> Void
    ) {
        self.products = products
        self.onAddToCart = onAddToCart
        self.onGoToCart = onGoToCart
        self.onCheckout = onCheckout
    }
}
