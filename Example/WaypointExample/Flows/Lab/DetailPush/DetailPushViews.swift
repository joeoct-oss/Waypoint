//
//  DetailPushViews.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The Detail push flow's shop list: every product, and a tap reports the one picked.
struct DetailPushListView: View {
    let onSelect: (Product) -> Void

    var body: some View {
        List {
            ForEach(Product.all) { product in
                ProductRow(product: product) { onSelect(product) }
            }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.detailList)
    }
}

// A product in the Detail push flow: its picture and details, a banner whose button pops back to
// the cart, and Add to cart at the bottom. The view only reports taps.
struct DetailPushProductView: View {
    let product: Product
    let onAddToCart: () -> Void
    let onBackToCart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                picture
                titles
                backToCartBanner
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.detailProduct)
        .bottomActionBar { addToCartButton }
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
            Text(product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.headline)
                .foregroundStyle(Palette.accent.color)
            Text(product.summary)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .foregroundStyle(Palette.text.color)
    }

    private var backToCartBanner: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            LabNote(
                title: "Back to cart",
                detail: "The banner calls popTo(DetailCartRoute.self, else: .popToRoot). "
                    + "Until Add to cart pushes it, this stack holds only Shop and the product."
            )
            Button("Back to cart", systemImage: "arrow.uturn.backward", action: onBackToCart)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier(Identifiers.detailBackToCart)
        }
    }

    private var addToCartButton: some View {
        PrimaryActionButton(
            title: "Add to cart",
            identifier: Identifiers.detailAddToCart,
            action: onAddToCart
        )
        .padding(Spacing.large)
    }
}

// The cart in the Detail push flow: the product that pushed it, one of it, and the total.
struct DetailPushCartView: View {
    let product: Product

    var body: some View {
        List {
            Section {
                ProductRowContent(product: product, detail: "Qty 1")
            }
            Section {
                LabeledContent("Total") {
                    Text(product.price, format: .currency(code: "USD"))
                }
                .font(Typography.headline)
            }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.detailCart)
    }
}
