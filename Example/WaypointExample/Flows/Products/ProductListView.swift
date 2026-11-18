//
//  ProductListView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Shop: the "Nebula nights" banner, two products picked as cards, then the rest of the shop as
// rows, with Filter in the navigation bar. The screen reports each choice.
struct ProductListView: View {
    private static let pickedCount = 2

    let onSelect: (Product) -> Void
    let onSelectCollection: (ProductCollection) -> Void
    let onFilter: () -> Void

    private var picked: [Product] {
        Array(Product.all.prefix(Self.pickedCount))
    }

    private var newThisWeek: [Product] {
        Array(Product.all.dropFirst(Self.pickedCount))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text("Small things for long nights")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textTertiary.color)
                CollectionBanner(collection: .nebulaNights) { onSelectCollection(.nebulaNights) }
                pickedSection
                newSection
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.productList)
        .toolbar { toolbarItems }
    }

    private var pickedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ShopSectionHeader(title: "Picked for you")
            HStack(alignment: .top, spacing: Spacing.medium) {
                ForEach(picked) { product in
                    ProductCard(product: product) { onSelect(product) }
                }
            }
        }
    }

    private var newSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ShopSectionHeader(title: "New this week")
            ProductRowCard(products: newThisWeek, onSelect: onSelect)
        }
    }

    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filter", systemImage: "line.3.horizontal.decrease", action: onFilter)
        }
    }
}

// A section's small uppercase title on Shop.
struct ShopSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Typography.label)
            .textCase(.uppercase)
            .foregroundStyle(Palette.textTertiary.color)
            .padding(.horizontal, Spacing.extraSmall)
            .accessibilityAddTraits(.isHeader)
    }
}

// Products as rows inside one card, divided by hairlines, for screens that scroll on their own
// instead of using a list.
struct ProductRowCard: View {
    let products: [Product]
    let onSelect: (Product) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(products) { product in
                makeRow(for: product)
            }
        }
        .padding(.horizontal, Spacing.large)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(border)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .strokeBorder(Palette.line.color)
    }

    @ViewBuilder
    private func makeRow(for product: Product) -> some View {
        Button {
            onSelect(product)
        } label: {
            ProductRowContent(product: product, detail: product.category)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.text.color)
        .accessibilityIdentifier(Identifiers.product(id: product.id))
        if product != products.last {
            Divider()
                .overlay(Palette.line.color)
        }
    }
}
