//
//  CartFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the cart's stack and its full-screen checkout from their coordinator.
struct CartFlowView: View {
    let cart: CartCoordinator

    var body: some View {
        NavigationStack {
            cart.makeCartFlow()
        }
        .fullScreenCover(isPresented: Binding(reading: cart.isCheckingOut, writing: cart.syncCheckout)) {
            cart.makeCheckoutFlow()
        }
    }
}
