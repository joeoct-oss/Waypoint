//
//  FeatureScreens.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCart
import ExampleProducts
import ExampleStore
import SwiftUI

// The screens one feature shows from another, which the app builds and hands in through the
// features' dependency structs, so no feature names another feature's types (planning #445): the
// Cart feature's cart, which Go to cart pushes on Shop, and the Products feature's wish list, which
// the Account tab pushes.
enum FeatureScreens {
    // The wish list pushed on Account suggests nothing; only the wish list sheet on Shop does.
    private static let noSuggestions: [Product] = []

    static func cart(_ screen: ShopCartScreen) -> AnyView {
        let cart = CartView(
            products: screen.products,
            onCheckout: screen.onCheckout,
            onShopMore: screen.onShopMore
        )
        return AnyView(cart)
    }

    static func wishlist(_ products: [Product]) -> AnyView {
        let wishlist = WishlistView(
            products: products,
            suggestions: noSuggestions,
            onSave: nil,
            onDone: nil
        )
        return AnyView(wishlist)
    }
}
