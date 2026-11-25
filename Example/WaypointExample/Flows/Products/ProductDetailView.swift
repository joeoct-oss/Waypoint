//
//  ProductDetailView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// A product: its illustration on a wide backdrop, name, price and description, its reviews, a
// related product the coordinator links to, Share and Save to the wish list in the bar, and Add to
// cart at the bottom, for guests and signed-in readers alike.
//
// Conformances:
// - `Related: View`: the link to the related product, which the coordinator draws.
struct ProductDetailView<Related: View>: View {
    // Computed, because a generic type can't keep a static stored property.
    private static var rating: String {
        "4.8 out of 5"
    }

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
                reviewsRow
                relatedSection
            }
            .padding(Spacing.large)
        }
        .bottomActionBar { addButton }
        .toolbar { barItems }
    }

    // Share and Save share one glass capsule in the bar.
    private var barItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ShareLink(item: "\(product.name) at Orbit Shop")
                .accessibilityIdentifier(Identifiers.productShare)
            Button("Save", systemImage: "heart", action: onSave)
                .accessibilityIdentifier(Identifiers.productSave)
        }
    }

    private var reviewsRow: some View {
        LabeledContent("Reviews") {
            Label(Self.rating, systemImage: "star.fill")
                .foregroundStyle(Palette.textSecondary.color)
        }
        .font(Typography.callout)
        .foregroundStyle(Palette.text.color)
        .padding(Spacing.medium)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.field))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.productReviews)
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
