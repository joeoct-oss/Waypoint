//
//  ProductListView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Shop: every product, with Filter in the navigation bar. The screen reports each choice.
struct ProductListView: View {
    let onSelect: (Product) -> Void
    let onFilter: () -> Void

    var body: some View {
        List(Product.all) { product in
            ProductRow(product: product) { onSelect(product) }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.productList)
        .toolbar { toolbarItems }
    }

    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filter", systemImage: "line.3.horizontal.decrease", action: onFilter)
        }
    }
}
