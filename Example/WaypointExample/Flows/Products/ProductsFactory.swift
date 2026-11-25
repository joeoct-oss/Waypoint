//
//  ProductsFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Builds Shop and Search from `ProductsDependencies`: each stack's coordinator, Search's view
// model, and every screen they show, from the catalog they were given. The coordinator passes in
// what each screen reports, so navigation stays in the coordinator.
struct ProductsFactory {
    private static let suggestionCount = 3

    // What the feature uses, which its coordinator reads too.
    let dependencies: ProductsDependencies

    init(dependencies: ProductsDependencies) {
        self.dependencies = dependencies
    }

    // A products stack starting at Shop or Search. Waypoint makes its router, which the main tabs
    // make the stack every tab shares.
    func makeCoordinator(
        start: ProductsStart,
        cart: ProductsCart
    ) -> ProductsCoordinator {
        ProductsCoordinator(
            factory: self,
            start: start,
            cart: cart
        )
    }

    // Search's view model on `router`, which declares the shop on that stack.
    func makeSearchModel(on router: StackRouter) -> SearchModel {
        SearchModel.onShopStack(router, catalog: dependencies.catalog)
    }

    func makeSearch(model: SearchModel) -> SearchView {
        SearchView(model: model)
    }

    func makeProductList(
        cart: [Product],
        onGoToCart: @escaping () -> Void,
        onSelect: @escaping (Product) -> Void,
        onSelectCollection: @escaping (ProductCollection) -> Void
    ) -> ProductListView {
        ProductListView(
            products: dependencies.catalog.products,
            cart: cart,
            onGoToCart: onGoToCart,
            onSelect: onSelect,
            onSelectCollection: onSelectCollection
        )
    }

    // The product the route carries: the one the list handed over, else the catalog's with the
    // route's id, or `nil` when the catalog has none.
    func makeProductDetail<Related: View>(
        for route: ProductRoute,
        onAddToCart: @escaping (Product) -> Void,
        onSave: @escaping (Product) -> Void,
        related: @escaping (Product) -> Related
    ) -> ProductDetailView<Related>? {
        guard let product = route.preview ?? dependencies.catalog.product(id: route.id) else {
            return nil
        }
        return ProductDetailView(
            product: product,
            onAddToCart: { onAddToCart(product) },
            onSave: { onSave(product) },
            related: { related(product) }
        )
    }

    // The collection the banner handed over, else the one with the route's id, or `nil`.
    func makeCollection(
        for route: CollectionRoute,
        onSelect: @escaping (Product) -> Void
    ) -> CollectionView? {
        guard let collection = route.preview ?? ProductCollection.find(id: route.id) else {
            return nil
        }
        return CollectionView(
            collection: collection,
            onSelect: onSelect
        )
    }

    func makeFilters(onApply: @escaping () -> Void) -> FilterView {
        FilterView(onApply: onApply)
    }

    func makeSaved(onViewWishlist: @escaping () -> Void) -> SavedView {
        SavedView(onViewWishlist: onViewWishlist)
    }

    // The wish list of `productIDs`, with up to three products not on it as suggestions.
    func makeWishlist(
        productIDs: [Int],
        onSave: @escaping (Product) -> Void,
        onDone: @escaping () -> Void
    ) -> WishlistView {
        let catalog = dependencies.catalog
        let suggestions = catalog.products
            .filter { !productIDs.contains($0.id) }
            .prefix(Self.suggestionCount)
        return WishlistView(
            products: catalog.products(withIDs: productIDs),
            suggestions: Array(suggestions),
            onSave: onSave,
            onDone: onDone
        )
    }
}
