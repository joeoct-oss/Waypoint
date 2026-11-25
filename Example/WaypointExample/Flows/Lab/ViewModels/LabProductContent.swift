//
//  LabProductContent.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// The demo product page every navigation style draws: the Orbit Lamp, a note on who pushes, and
// Reviews (when the style shows them) and Add to cart at the bottom. The content only reports taps;
// each style's view decides what a tap does.
struct LabProductContent: View {
    static let product = Product.all[0]

    let note: String
    let detail: String
    let isLoadingReviews: Bool
    let onReviews: (() -> Void)?
    let onAddToCart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                picture
                titles
                LabNote(title: note, detail: detail)
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.labDemoProduct)
        .bottomActionBar { buttons }
    }

    private var picture: some View {
        ProductIllustration(artwork: Self.product.artwork, drawsBackdrop: false)
            .frame(maxWidth: .infinity)
            .frame(height: Size.productHero)
            .background(ProductBackdrop(artwork: Self.product.artwork))
            .clipShape(RoundedRectangle(cornerRadius: Radius.banner))
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(Self.product.name)
                .font(Typography.title)
            Text(Self.product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.headline)
                .foregroundStyle(Palette.accent.color)
            Text(Self.product.summary)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .foregroundStyle(Palette.text.color)
    }

    private var buttons: some View {
        HStack(spacing: Spacing.medium) {
            reviewsButton
            PrimaryActionButton(
                title: "Add to cart",
                identifier: Identifiers.labDemoAddToCart,
                action: onAddToCart
            )
        }
        .padding(Spacing.large)
    }

    @ViewBuilder
    private var reviewsButton: some View {
        if let onReviews {
            Button(action: onReviews) {
                Text(isLoadingReviews ? "Loading…" : "Reviews")
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(isLoadingReviews)
            .accessibilityIdentifier(Identifiers.labDemoReviews)
        }
    }
}

// A note in the Lab's demos: a bold line saying what happened, and a line saying why.
struct LabNote: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(title)
                .font(Typography.callout.weight(.semibold))
                .foregroundStyle(Palette.text.color)
            Text(detail)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(Palette.brandSubtle.color, in: RoundedRectangle(cornerRadius: Radius.field))
        .accessibilityElement(children: .combine)
    }
}

// The demo cart the product pushes, in every style.
struct LabCartView: View {
    var body: some View {
        ContentUnavailableView(
            "Added to cart",
            systemImage: "cart.badge.plus",
            description: Text("The same push, whichever style made it.")
        )
        .accessibilityIdentifier(Identifiers.labDemoCart)
    }
}

// The demo reviews the product's view model pushes once they load.
struct LabReviewsView: View {
    var body: some View {
        ContentUnavailableView(
            "4.8 out of 5",
            systemImage: "star.bubble",
            description: Text("The reviews arrived while you were still here, so the model pushed them.")
        )
        .accessibilityIdentifier(Identifiers.labDemoReviewsScreen)
    }
}
