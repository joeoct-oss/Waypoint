//
//  ProductListView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Shop: the "Nebula nights" banner, two products picked as cards, then the rest of the shop as
// rows. Filter and Wish list are `ShopToolbar`, which the main tabs put in the navigation bar. The
// screen reports each choice.
struct ProductListView: View {
    private static let pickedCount = 2

    let cart: [Product]
    let onGoToCart: () -> Void
    let onSelect: (Product) -> Void
    let onSelectCollection: (ProductCollection) -> Void

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
                cartCard
                CollectionBanner(collection: .nebulaNights) { onSelectCollection(.nebulaNights) }
                pickedSection
                newSection
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.productList)
    }

    // "Your cart is waiting", while the cart has products.
    @ViewBuilder
    private var cartCard: some View {
        if let first = cart.first {
            CartWaitingCard(
                first: first,
                count: cart.count,
                onGoToCart: onGoToCart
            )
        }
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
}

// Shop's Wish list and Filter buttons. The main tabs show them in the navigation bar while Shop is
// selected, since the tab roots share the bar of the one stack around the tabs.
//
// Conformances:
// - `ToolbarContent`, so the main tabs can put it in their toolbar.
struct ShopToolbar: ToolbarContent {
    let onFilter: () -> Void
    let onWishlist: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Wish list", systemImage: "heart", action: onWishlist)
                .accessibilityIdentifier(Identifiers.shopWishlist)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filter", systemImage: "line.3.horizontal.decrease", action: onFilter)
                .accessibilityIdentifier(Identifiers.filterButton)
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

// Shop's "Your cart is waiting" card: the cart's first product, how many more there are, and Go to
// cart, which the card only reports.
struct CartWaitingCard: View {
    let first: Product
    let count: Int
    let onGoToCart: () -> Void

    private var summary: String {
        count > 1 ? "\(first.name) and \(count - 1) more" : first.name
    }

    var body: some View {
        HStack(spacing: Spacing.medium) {
            IconTile(
                symbolName: "cart",
                size: Size.rowIcon,
                tint: Palette.brand,
                fill: Palette.brandSubtle
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("Your cart is waiting")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.text.color)
                Text(summary)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textTertiary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Go to cart", action: onGoToCart)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier(Identifiers.goToCart)
        }
        .padding(Spacing.large)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Palette.line.color))
    }
}
