//
//  ProductDetailView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A product: its picture, name, price and description, a related product the coordinator links
// to, Save to the wish list in the bar and Add to cart at the bottom, for guests and signed-in
// readers alike.
//
// Conformances:
// - `Related: View`: the link to the related product, which the coordinator draws.
struct ProductDetailView<Related: View>: View {
    let product: Product
    let onAddToCart: () -> Void
    let onSave: () -> Void
    @ViewBuilder let related: Related

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
                relatedSection
            }
            .padding(Spacing.large)
        }
        .bottomActionBar { addButton }
        .toolbar { saveItem }
    }

    private var saveItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save", systemImage: "heart", action: onSave)
                .accessibilityIdentifier(Identifiers.productSave)
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("You might also like")
                .font(Typography.headline)
                .foregroundStyle(Palette.text.color)
            related
                .buttonStyle(.plain)
                .accessibilityIdentifier(Identifiers.relatedProduct)
        }
        .padding(.top, Spacing.large)
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
