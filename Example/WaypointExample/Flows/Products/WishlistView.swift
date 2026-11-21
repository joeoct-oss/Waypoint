//
//  WishlistView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The wish list: the products the reader saved. As a sheet it can grow, closes with Done, and
// suggests a few more products under "You may also like", each with Save, which the sheet only
// reports. Pushed from Account it has no Done and no suggestions.
struct WishlistView: View {
    private static let suggestionsTitle = "You may also like"
    private static let emptyLine = "Nothing saved yet."
    private static let saveTitle = "Save"

    let products: [Product]
    let suggestions: [Product]
    let onSave: ((Product) -> Void)?
    let onDone: (() -> Void)?

    var body: some View {
        list
            .navigationTitle("Wish list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneItem }
            // Contains its children, so the Save buttons keep their own identifiers.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(Identifiers.wishlist)
    }

    private var list: some View {
        List {
            savedSection
            suggestionsSection
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        if products.isEmpty {
            Text(Self.emptyLine)
                .foregroundStyle(Palette.textSecondary.color)
        } else {
            ForEach(products) { product in
                makeRow(for: product)
            }
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if let onSave, !suggestions.isEmpty {
            Section(Self.suggestionsTitle) {
                ForEach(suggestions) { product in
                    makeSuggestion(
                        for: product,
                        onSave: onSave
                    )
                }
            }
        }
    }

    private var doneItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if let onDone {
                Button("Done", action: onDone)
                    .accessibilityIdentifier(Identifiers.wishlistDone)
            }
        }
    }

    private func makeRow(for product: Product) -> some View {
        HStack(spacing: Spacing.medium) {
            ProductIllustration(artwork: product.artwork, drawsBackdrop: true)
                .frame(width: Size.rowIcon, height: Size.rowIcon)
                .clipShape(RoundedRectangle(cornerRadius: Radius.field))
            LabeledContent(product.name) {
                Text(product.price, format: .currency(code: "USD").precision(.fractionLength(0)))
            }
        }
    }

    private func makeSuggestion(
        for product: Product,
        onSave: @escaping (Product) -> Void
    ) -> some View {
        HStack(spacing: Spacing.medium) {
            makeRow(for: product)
            Button(Self.saveTitle) { onSave(product) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(Identifiers.wishlistSave(id: product.id))
        }
    }
}
