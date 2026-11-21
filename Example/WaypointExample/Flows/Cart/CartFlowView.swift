//
//  CartFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws the cart's stack and its full-screen checkout from their coordinator. Checkout shows the
// account gate's notice too, since its cover hides the one over the tabs.
struct CartFlowView: View {
    let cart: CartCoordinator

    var body: some View {
        WaypointStack(cart.router) {
            cart.makeCartFlow()
        }
        .fullScreenCover(
            isPresented: Binding(reading: cart.isCheckingOut, writing: cart.syncCheckout),
            onDismiss: cart.releaseCheckout
        ) {
            cart.makeCheckoutFlow()
                .noticeOverlay(cart.accountNotice)
        }
    }
}
