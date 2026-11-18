//
//  ProductsFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws a products stack and its sheets from their coordinator, with the newest navigation issue
// over the stack when there is one.
struct ProductsFlowView: View {
    let products: ProductsCoordinator

    var body: some View {
        WaypointStack(products.router) {
            products.makeRootFlow()
                .destination(ProductRoute.self) { products.makeProductFlow(for: $0) }
                .task { await products.playLaunchSteps() }
        }
        .overlay(alignment: .bottom) { IssueBanner(issues: products.issues) }
        .sheet(item: Binding(reading: products.presentedSheet, writing: products.syncSheet)) {
            products.makeSheetFlow(for: $0)
        }
    }
}
