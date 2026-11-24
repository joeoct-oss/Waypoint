//
//  DetailPushRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// The Lab's Detail push flow: the shop list at the root, a product pushed above it, and the cart
// pushed above the product.
//
// Conformances:
// - `NavigationFlow`, so the flow's routes name it and its stack is declared for it.
enum DetailPushFlow: NavigationFlow { }

// A product in the Detail push flow, pushed from the shop list.
//
// Conformances:
// - `Route`, so the flow's stack router can push it and find its destination.
struct DetailProductRoute: Route {
    typealias Flow = DetailPushFlow

    let productID: Int
}

// The cart in the Detail push flow, pushed by the product's Add to cart.
//
// Conformances:
// - `Route`, so the flow's stack router can push it, pop to it and find its destination.
struct DetailCartRoute: Route {
    typealias Flow = DetailPushFlow

    let productID: Int
}

// The review's note in the Write a review flow, pushed by the rating screen with the stars picked.
// It names no flow, so the review flow's own stack router pushes it.
//
// Conformances:
// - `Route`, so the review flow's router can push it and find its destination.
struct DetailReviewNoteRoute: Route {
    let rating: Int
}
