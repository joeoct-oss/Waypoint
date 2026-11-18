//
//  ProductDetailView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A product: its illustration on a wide backdrop, name, price and description, a related product
// the coordinator links to, Save to the wish list in the bar and Add to cart at the bottom, for
// guests and signed-in readers alike.
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
                titles
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
        ProductIllustration(artwork: product.artwork, drawsBackdrop: false)
            .frame(maxWidth: .infinity)
            .frame(height: Size.productHero)
            .background(ProductBackdrop(artwork: product.artwork))
            .clipShape(RoundedRectangle(cornerRadius: Radius.banner))
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(product.name)
                .font(Typography.title)
                .foregroundStyle(Palette.text.color)
            Text(product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.headline)
                .foregroundStyle(Palette.accent.color)
        }
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
