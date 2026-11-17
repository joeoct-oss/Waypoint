//
//  ProductListView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Shop: every product, with a filter button in the navigation bar. The screen reports the product or the
// filter the reader picks.
struct ProductListView: View {
    let onSelect: (Product) -> Void
    let onFilter: () -> Void

    var body: some View {
        List(Product.all) { product in
            ProductRow(product: product) { onSelect(product) }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.productList)
        .toolbar { filterItem }
    }

    private var filterItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filter", systemImage: "line.3.horizontal.decrease", action: onFilter)
        }
    }
}
