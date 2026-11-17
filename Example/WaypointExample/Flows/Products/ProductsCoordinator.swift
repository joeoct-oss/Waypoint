//
//  ProductsCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A stack of products: the shop or search at the root, a product pushed above it, and the filter sheet
// presented over the shop. Add to cart reports to the main tabs, which open Cart.
//
// Conformances:
// - `Observable` (from `@Observable`), so `ProductsFlowView` redraws when the path or the sheet changes.
@MainActor
@Observable
final class ProductsCoordinator {
    private let start: ProductsStart
    private let onShowCart: () -> Void
    // `var` because `showProduct(_:)` pushes onto it, and `syncPath(_:)` takes the pops the stack makes
    // itself.
    private(set) var path: [ProductScreen]
    // `var` because `showFilters()` and `dismissFilters()` change it, and `syncFilters(_:)` takes a swipe down.
    private(set) var isShowingFilters: Bool

    init(
        start: ProductsStart,
        onShowCart: @escaping () -> Void
    ) {
        self.start = start
        self.onShowCart = onShowCart
        path = []
        isShowingFilters = false
    }

    @ViewBuilder
    func makeRootFlow() -> some View {
        switch start {
        case .browse:
            makeShopFlow()
        case .search:
            makeSearchFlow()
        }
    }

    @ViewBuilder
    func makeDestination(for screen: ProductScreen) -> some View {
        switch screen {
        case .product(let product):
            makeProductFlow(product)
        }
    }

    func makeFiltersFlow() -> some View {
        FilterView(onApply: { self.dismissFilters() })
    }

    func showProduct(_ product: Product) {
        path.append(.product(product))
    }

    func showFilters() {
        isShowingFilters = true
    }

    func showCart() {
        onShowCart()
    }

    func dismissFilters() {
        isShowingFilters = false
    }

    func syncPath(_ newPath: [ProductScreen]) {
        path = newPath
    }

    func syncFilters(_ isShowing: Bool) {
        isShowingFilters = isShowing
    }

    private func makeShopFlow() -> some View {
        ProductListView(
            onSelect: { self.showProduct($0) },
            onFilter: { self.showFilters() }
        )
        .screenChrome(
            title: MainTab.shop.title,
            kind: nil,
            trail: ProductsTrail.shop
        )
    }

    private func makeSearchFlow() -> some View {
        SearchView(onSelect: { self.showProduct($0) })
            .screenChrome(
                title: MainTab.search.title,
                kind: nil,
                trail: ProductsTrail.search
            )
    }

    private func makeProductFlow(_ product: Product) -> some View {
        ProductDetailView(
            product: product,
            onAddToCart: { self.showCart() }
        )
        .screenChrome(
            title: product.name,
            kind: nil,
            trail: ProductsTrail.product(product, from: start)
        )
    }
}

// The route trail for each products screen.
enum ProductsTrail {
    static let shop = [
        "shop",
    ]
    static let search = [
        "search",
    ]

    static func product(
        _ product: Product,
        from start: ProductsStart
    ) -> [String] {
        let root = start == .browse ? shop : search
        let step = product.name.lowercased()
        return root + [step]
    }
}
