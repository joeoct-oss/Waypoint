//
//  ProductDetailView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A product: its picture, name, price and description, with Save to the wish list in the bar and
// Add to cart for signed-in readers.
struct ProductDetailView: View {
    let product: Product
    let canBuy: Bool
    let onAddToCart: () -> Void
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                picture
                Text(product.price, format: .currency(code: "USD"))
                    .font(Typography.title)
                    .foregroundStyle(Palette.text.color)
                Text(product.summary)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            .padding(Spacing.large)
        }
        .bottomActionBar { bottomBar }
        .toolbar { saveItem }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if canBuy {
            addButton
        }
    }

    private var saveItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save", systemImage: "heart", action: onSave)
                .accessibilityIdentifier(Identifiers.productSave)
        }
    }

    private var picture: some View {
        Image(systemName: product.symbolName)
            .font(.system(size: 72))
            .foregroundStyle(Palette.brand.color)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(Palette.brandSubtle.color, in: RoundedRectangle(cornerRadius: Radius.card))
            .accessibilityHidden(true)
    }

    private var addButton: some View {
        PrimaryActionButton(
            title: "Add to cart",
            identifier: Identifiers.addToCart,
            action: onAddToCart
        )
        .padding(Spacing.large)
    }
}
