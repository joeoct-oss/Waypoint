//
//  ProductsCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A stack of products: the shop or search at the root and a product pushed above it, with the
// filters and the wish list as sheets. Add to cart reports to the main tabs, which add the product
// to the cart and open Cart. Save needs an account, so the account gate asks a guest to sign in
// first; then the product joins the wish list, which the local store keeps.
//
// Conformances:
// - `Observable` (from `@Observable`), so `ProductsFlowView` redraws when the path or the sheet
//   changes.
@MainActor
@Observable
final class ProductsCoordinator {
    private let start: ProductsStart
    private let store: LocalStore
    private let gate: AccountGate
    private let onAddToCart: (Product) -> Void
    // `var` because `showProduct(_:)` pushes onto it, and `syncPath(_:)` takes the pops the stack
    // makes itself.
    private(set) var path: [ProductScreen]
    // `var` because `showFilters()`, `showWishlist()` and `dismissSheet()` change it, and
    // `syncSheet(_:)` takes a swipe down.
    private(set) var presentedSheet: ProductSheet?

    init(
        start: ProductsStart,
        store: LocalStore,
        gate: AccountGate,
        onAddToCart: @escaping (Product) -> Void
    ) {
        self.start = start
        self.store = store
        self.gate = gate
        self.onAddToCart = onAddToCart
        path = []
        presentedSheet = nil
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

    @ViewBuilder
    func makeSheetFlow(for sheet: ProductSheet) -> some View {
        switch sheet {
        case .filters:
            makeFiltersFlow()
        case .wishlist:
            makeWishlistFlow()
        }
    }

    func showProduct(_ product: Product) {
        path.append(.product(product))
    }

    func showFilters() {
        presentedSheet = .filters
    }

    func showWishlist() {
        presentedSheet = .wishlist
    }

    func addToCart(_ product: Product) {
        onAddToCart(product)
    }

    func save(_ product: Product) {
        gate.requireAccount { self.addToWishlist(product) }
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func syncPath(_ newPath: [ProductScreen]) {
        path = newPath
    }

    func syncSheet(_ sheet: ProductSheet?) {
        presentedSheet = sheet
    }

    private func addToWishlist(_ product: Product) {
        if !store.wishlistProductIDs.contains(product.id) {
            store.wishlistProductIDs.append(product.id)
        }
        showWishlist()
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

    private func makeFiltersFlow() -> some View {
        FilterView(onApply: { self.dismissSheet() })
    }

    private func makeWishlistFlow() -> some View {
        WishlistView(
            products: Product.products(withIDs: store.wishlistProductIDs),
            onDone: { self.dismissSheet() }
        )
    }

    private func makeProductFlow(_ product: Product) -> some View {
        ProductDetailView(
            product: product,
            onAddToCart: { self.addToCart(product) },
            onSave: { self.save(product) }
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
