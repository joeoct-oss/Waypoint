//
//  ProductsFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws a products stack and its sheets from their coordinator; the main tabs show the newest
// navigation issue over it. The stack hides the tab bar on every screen pushed above the
// tab's root.
struct ProductsFlowView: View {
    let products: ProductsCoordinator

    var body: some View {
        WaypointStack(products.router) {
            products.makeRootFlow()
                .destination(ProductRoute.self) { products.makeProductFlow(for: $0) }
                .destination(CollectionRoute.self) { products.makeCollectionFlow(for: $0) }
                .destination(ShopCartRoute.self) { _ in products.makeCartFlow() }
                .task { await products.playLaunchSteps() }
        }
        .tabBarOnPushedScreens(.hidden)
        .sheet(
            isPresented: Binding(reading: products.isShowingSheet, writing: products.syncSheet),
            onDismiss: products.releaseSheet
        ) {
            products.makeSheetFlow()
        }
    }
}
