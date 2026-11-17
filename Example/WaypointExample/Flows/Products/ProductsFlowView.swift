//
//  ProductsFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws a products stack and its sheets from their coordinator.
struct ProductsFlowView: View {
    let products: ProductsCoordinator

    var body: some View {
        NavigationStack(path: Binding(reading: products.path, writing: products.syncPath)) {
            products.makeRootFlow()
                .navigationDestination(for: ProductScreen.self) { products.makeDestination(for: $0) }
        }
        .sheet(item: Binding(reading: products.presentedSheet, writing: products.syncSheet)) {
            products.makeSheetFlow(for: $0)
        }
    }
}
