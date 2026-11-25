//
//  ProductRow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleStore
import SwiftUI

// One product in a list: its illustration, name, a detail line (its category, or the quantity in
// the cart), its price and a chevron, because a tap opens it.
package struct ProductRow: View {
    package let product: Product
    package let detail: String
    package let onSelect: () -> Void

    package init(
        product: Product,
        detail: String? = nil,
        onSelect: @escaping () -> Void
    ) {
        self.product = product
        self.detail = detail ?? product.category
        self.onSelect = onSelect
    }

    package var body: some View {
        Button(action: onSelect) {
            ProductRowContent(product: product, detail: detail)
        }
        .foregroundStyle(Palette.text.color)
        .accessibilityIdentifier(Identifiers.product(id: product.id))
        .exampleRow()
    }
}

// What a product row shows, shared by lists and the cards of Shop's sections.
package struct ProductRowContent: View {
    package let product: Product
    package let detail: String

    package init(
        product: Product,
        detail: String
    ) {
        self.product = product
        self.detail = detail
    }

    package var body: some View {
        HStack(spacing: Spacing.medium) {
            ProductIllustration(artwork: product.artwork, drawsBackdrop: true)
                .frame(width: Size.productThumbnail, height: Size.productThumbnail)
                .clipShape(RoundedRectangle(cornerRadius: Radius.field))
            titles
            Text(product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.callout.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(Typography.footnote.weight(.semibold))
                .foregroundStyle(Palette.textTertiary.color)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.small)
        .contentShape(Rectangle())
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(product.name)
                .font(Typography.headline)
            Text(detail)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
