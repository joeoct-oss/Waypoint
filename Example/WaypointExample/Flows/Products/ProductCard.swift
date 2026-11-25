//
//  ProductCard.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// A product as a card in Shop's "Picked for you": its illustration across the card's width, then
// its name and price. The card reports a tap.
package struct ProductCard: View {
    package let product: Product
    package let onSelect: () -> Void

    package var body: some View {
        Button(action: onSelect) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Identifiers.product(id: product.id))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ProductIllustration(artwork: product.artwork, drawsBackdrop: true)
                .clipShape(RoundedRectangle(cornerRadius: Radius.field))
            Text(product.name)
                .font(Typography.callout.weight(.semibold))
                .foregroundStyle(Palette.text.color)
            Text(product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(cardBorder)
        .accessibilityElement(children: .combine)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .strokeBorder(Palette.line.color)
    }
}
