//
//  DetailPushViews.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// The Detail push flow's shop list: every product, and a tap reports the one picked.
package struct DetailPushListView: View {
    package let products: [Product]
    package let onSelect: (Product) -> Void
    package let onClose: () -> Void

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: onClose)
                .accessibilityIdentifier(Identifiers.labDemoClose)
        }
    }

    package var body: some View {
        List {
            ForEach(products) { product in
                ProductRow(product: product) { onSelect(product) }
            }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.detailList)
        .toolbar { closeItem }
    }
}

// A product in the Detail push flow: its picture and details, the review it got, a banner whose
// button pops back to the cart, Write a review in the navigation bar, and Add to cart at the
// bottom. The view only reports taps.
package struct DetailPushProductView: View {
    package let product: Product
    // The stars of the review posted for this product, or `nil` before one is.
    package let postedReview: Int?
    package let onAddToCart: () -> Void
    package let onBackToCart: () -> Void
    package let onWriteReview: () -> Void

    package var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                picture
                titles
                reviewBanner
                backToCartBanner
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.detailProduct)
        .toolbar { writeReviewItem }
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

    // In the navigation bar, so Add to cart's bar never covers it.
    private var writeReviewItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Write a review", systemImage: "star", action: onWriteReview)
                .accessibilityIdentifier(Identifiers.detailWriteReview)
        }
    }

    private var reviewBanner: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            LabNote(
                title: "Write a review",
                detail: "The star in the bar pushes a child flow on this stack with "
                    + "push(_:onFinish:). Its result comes back here once."
            )
            if let postedReview {
                Text("Your review: \(DetailReviewText.stars(postedReview))")
                    .font(Typography.headline)
                    .accessibilityIdentifier(Identifiers.detailReviewPosted)
            }
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
package struct DetailPushCartView: View {
    package let product: Product

    package var body: some View {
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
