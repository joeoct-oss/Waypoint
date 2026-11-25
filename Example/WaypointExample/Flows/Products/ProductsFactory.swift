//
//  ProductsFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleStore
import SwiftUI
import Waypoint

// Builds Shop and Search from `ProductsDependencies`: each stack's coordinator, Search's view
// model, and every screen they show, from the catalog they were given. The coordinator passes in
// what each screen reports, so navigation stays in the coordinator.
package struct ProductsFactory {
    private static let suggestionCount = 3

    // What the feature uses, which its coordinator reads too.
    package let dependencies: ProductsDependencies

    package init(dependencies: ProductsDependencies) {
        self.dependencies = dependencies
    }

    // A products stack starting at Shop or Search. Waypoint makes its router, which the main tabs
    // make the stack every tab shares.
    package func makeCoordinator(
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
    package func makeSearchModel(on router: StackRouter) -> SearchModel {
        SearchModel.onShopStack(router, catalog: dependencies.catalog)
    }

    package func makeSearch(model: SearchModel) -> SearchView {
        SearchView(model: model)
    }

    package func makeProductList(
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
    package func makeProductDetail<Related: View>(
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
    package func makeCollection(
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

    // The cart Go to cart pushes above a product, showing the Cart tab's `products`: the Cart
    // feature's screen, which the app hands in.
    package func makeCart(
        products: [Product],
        onCheckout: @escaping () -> Void,
        onShopMore: @escaping () -> Void
    ) -> AnyView {
        let screen = ShopCartScreen(
            products: products,
            onCheckout: onCheckout,
            onShopMore: onShopMore
        )
        return dependencies.cartScreen(screen)
    }

    // Links to `product` with `WaypointLink`, which pushes through the stack it is drawn on. When a
    // UI test passes the `systemLinks` launch argument, it gets a system `NavigationLink` instead,
    // which Waypoint refuses and reports. With `missingDestination`, the link pushes the product's
    // reviews, which no screen of the stack draws, so the stack shows its missing-destination
    // screen.
    @ViewBuilder
    package func makeRelatedLink(to product: Product) -> some View {
        let navigation = dependencies.navigation
        let route = ProductRoute(
            id: product.id,
            preview: product
        )
        if navigation.linksToMissingDestination {
            WaypointLink(value: ProductReviewsRoute(productID: product.id)) {
                RelatedProductRow(product: product)
            }
        } else if navigation.usesSystemLinks {
            NavigationLink(value: route) {
                RelatedProductRow(product: product)
            }
        } else {
            WaypointLink(value: route) {
                RelatedProductRow(product: product)
            }
        }
    }

    package func makeFilters(onApply: @escaping () -> Void) -> FilterView {
        FilterView(onApply: onApply)
    }

    package func makeSaved(onViewWishlist: @escaping () -> Void) -> SavedView {
        SavedView(onViewWishlist: onViewWishlist)
    }

    // The wish list's flow, on the store's wish list. Done on Signed in over it runs `onCloseAll`.
    package func makeWishlistFlow(onCloseAll: @escaping () -> Void) -> WishlistCoordinator {
        WishlistCoordinator(
            factory: self,
            onCloseAll: onCloseAll
        )
    }

    // The wish list of `productIDs`, with up to three products not on it as suggestions.
    package func makeWishlist(
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
