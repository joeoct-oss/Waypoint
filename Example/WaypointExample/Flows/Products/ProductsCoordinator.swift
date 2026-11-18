//
//  ProductsCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A stack of products: the shop or search at the root and a product pushed above it, with the filters
// and the wish list as sheets. Add to cart reports to the main tabs, which add the product to the cart and
// open Cart; a guest's Sign in
// reports to the app coordinator, which switches to the accounts flow.
//
// Conformances:
// - `Observable` (from `@Observable`), so `ProductsFlowView` redraws when the path or the sheet changes.
@MainActor
@Observable
final class ProductsCoordinator {
    private let start: ProductsStart
    private let membership: Membership
    private let onAddToCart: (Product) -> Void
    private let onShowAccounts: () -> Void
    // `var` because `showProduct(_:)` pushes onto it, and `syncPath(_:)` takes the pops the stack makes
    // itself.
    private(set) var path: [ProductScreen]
    // `var` because `showFilters()`, `showWishlist()` and `dismissSheet()` change it, and `syncSheet(_:)`
    // takes a swipe down.
    private(set) var presentedSheet: ProductSheet?

    init(
        start: ProductsStart,
        membership: Membership,
        onAddToCart: @escaping (Product) -> Void,
        onShowAccounts: @escaping () -> Void
    ) {
        self.start = start
        self.membership = membership
        self.onAddToCart = onAddToCart
        self.onShowAccounts = onShowAccounts
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

    func showAccounts() {
        onShowAccounts()
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

    private func makeShopFlow() -> some View {
        ProductListView(
            showsSignIn: membership == .guest,
            onSelect: { self.showProduct($0) },
            onFilter: { self.showFilters() },
            onSignIn: { self.showAccounts() }
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
            products: Product.sampleWishlist,
            onDone: { self.dismissSheet() }
        )
    }

    private func makeProductFlow(_ product: Product) -> some View {
        ProductDetailView(
            product: product,
            canBuy: membership == .member,
            onAddToCart: { self.addToCart(product) },
            onSave: { self.showWishlist() }
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
