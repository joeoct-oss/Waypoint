//
//  ProductRow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// One product in a list: its picture, name, price and summary.
struct ProductRow: View {
    let product: Product
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.medium) {
                IconTile(
                    symbolName: product.symbolName,
                    size: Size.cardIcon,
                    tint: Palette.brand,
                    fill: Palette.brandSubtle
                )
                titles
                Text(product.price, format: .currency(code: "USD"))
                    .font(Typography.callout.weight(.semibold))
            }
            .padding(.vertical, Spacing.extraSmall)
        }
        .foregroundStyle(Palette.text.color)
        .accessibilityIdentifier(Identifiers.product(id: product.id))
        .exampleRow()
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(product.name)
                .font(Typography.headline)
            Text(product.summary)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textSecondary.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
