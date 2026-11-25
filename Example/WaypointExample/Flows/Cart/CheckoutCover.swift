//
//  CheckoutCover.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import SwiftUI
import Waypoint

// The full-screen checkout. `MainTabView` gives it to the stack around the tabs, like every tab's
// presentations, since one on a tab's root doesn't show under a pushed screen. Checkout shows the
// account gate's notice too, since its cover hides the one over the tabs.
//
// Conformances:
// - `ViewModifier`, so `MainTabView` gives it to the stack.
struct CheckoutCover: ViewModifier {
    let cart: CartCoordinator

    func body(content: Content) -> some View {
        content.fullScreenCover(
            isPresented: Binding(reading: cart.isCheckingOut, writing: cart.syncCheckout),
            onDismiss: cart.releaseCheckout
        ) {
            cart.makeCheckoutFlow()
                .noticeOverlay(cart.accountNotice)
        }
    }
}
