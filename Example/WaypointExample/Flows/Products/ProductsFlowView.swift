//
//  ProductsFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws a products stack and its sheets from their coordinator.
struct ProductsFlowView: View {
    let products: ProductsCoordinator

    var body: some View {
        WaypointStack(products.router) {
            products.makeRootFlow()
                .destination(ProductRoute.self) { products.makeProductFlow(for: $0) }
                .task { await products.playLaunchSteps() }
        }
        .sheet(item: Binding(reading: products.presentedSheet, writing: products.syncSheet)) {
            products.makeSheetFlow(for: $0)
        }
    }
}
