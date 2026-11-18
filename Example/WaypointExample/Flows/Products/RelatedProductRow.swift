//
//  RelatedProductRow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A product the reader might also like, under a product's description: its illustration, name and
// price, with a chevron, because a tap opens it.
struct RelatedProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: Spacing.medium) {
            ProductIllustration(artwork: product.artwork, drawsBackdrop: true)
                .frame(width: Size.rowIcon, height: Size.rowIcon)
                .clipShape(RoundedRectangle(cornerRadius: Radius.field))
            Text(product.name)
                .font(Typography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.callout.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(Typography.footnote.weight(.semibold))
                .foregroundStyle(Palette.textTertiary.color)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Palette.text.color)
        .padding(Spacing.medium)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}
