//
//  ProductDetailView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A product: its picture, name, price and description, with Add to cart.
struct ProductDetailView: View {
    let product: Product
    let onAddToCart: () -> Void

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
        .safeAreaInset(edge: .bottom) { addButton }
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
            identifier: "product.addToCart",
            action: onAddToCart
        )
        .padding(Spacing.large)
    }
}
