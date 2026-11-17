//
//  ProductListView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Shop: every product, with Filter in the navigation bar, and Sign in for guests. The screen reports each
// choice.
struct ProductListView: View {
    let showsSignIn: Bool
    let onSelect: (Product) -> Void
    let onFilter: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        List(Product.all) { product in
            ProductRow(product: product) { onSelect(product) }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.productList)
        .toolbar { toolbarItems }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filter", systemImage: "line.3.horizontal.decrease", action: onFilter)
        }
        if showsSignIn {
            ToolbarItem(placement: .topBarLeading) {
                Button("Sign in", action: onSignIn)
                    .accessibilityIdentifier(Identifiers.guestSignIn)
            }
        }
    }
}
