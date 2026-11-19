//
//  ProductsCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint
import WaypointCore

// A stack of products: the shop or search at the root, a collection from Shop's banner and a
// product pushed above it, with the filters and the wish list as sheets. Add to cart reports to the
// main tabs, which add the product to the cart and open Cart. Save needs an account, so the account
// gate asks a guest to sign in first; then the product joins the wish list, which the local store
// keeps.
//
// The stack runs on Waypoint: `router`, the tab's stack router from the main tab router, owns the
// path, `ProductsFlowView` draws it with `WaypointStack`, and a swipe back comes back to the router
// by itself. The journey names the stack's first screen `Product list` or `Search`. A product page
// links to a related product with `WaypointLink`, which pushes through the same router. The sheets
// are still plain SwiftUI state until Waypoint's sheets are built.
//
// Conformances:
// - `Observable` (from `@Observable`), so `ProductsFlowView` redraws when the sheet changes.
@MainActor
@Observable
final class ProductsCoordinator {
    private static let followUpDelay = Duration.milliseconds(150)
    private static let linkedProductID = 4

    let router: StackRouter
    private let start: ProductsStart
    private let store: LocalStore
    private let gate: AccountGate
    private let launchSteps: ShopLaunchSteps
    private let navigation: ProductsNavigation
    private let onAddToCart: (Product) -> Void
    // `var` because `showFilters()`, `showWishlist()` and `dismissSheet()` change it, and
    // `syncSheet(_:)` takes a swipe down.
    private(set) var presentedSheet: ProductSheet?
    // `var` because `playLaunchSteps()` plays them once, and the shop appears again on every tab
    // switch.
    private var hasPlayedLaunchSteps: Bool

    var issues: IssueLog {
        navigation.issues
    }

    init(
        start: ProductsStart,
        router: StackRouter,
        store: LocalStore,
        gate: AccountGate,
        launchSteps: ShopLaunchSteps,
        navigation: ProductsNavigation,
        onAddToCart: @escaping (Product) -> Void
    ) {
        self.start = start
        self.store = store
        self.gate = gate
        self.launchSteps = launchSteps
        self.navigation = navigation
        self.onAddToCart = onAddToCart
        self.router = router
        router.setRootName(start.rootName)
        presentedSheet = nil
        hasPlayedLaunchSteps = false
        router.setCoordinator(self)
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

    // Shows the product the list handed over at once, or looks it up by id after a link or a
    // restore.
    @ViewBuilder
    func makeProductFlow(for route: ProductRoute) -> some View {
        if let product = route.preview ?? Product.find(id: route.id) {
            makeProductFlow(product)
        }
    }

    // Shows the collection the banner handed over, or looks it up by id after a restore.
    @ViewBuilder
    func makeCollectionFlow(for route: CollectionRoute) -> some View {
        if let collection = route.preview ?? ProductCollection.find(id: route.id) {
            makeCollectionFlow(collection)
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
        let route = ProductRoute(
            id: product.id,
            preview: product
        )
        router.push(route)
    }

    func showCollection(_ collection: ProductCollection) {
        let route = CollectionRoute(
            id: collection.id,
            preview: collection
        )
        router.push(route)
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

    func syncSheet(_ sheet: ProductSheet?) {
        presentedSheet = sheet
    }

    private func addToWishlist(_ product: Product) {
        if !store.wishlistProductIDs.contains(product.id) {
            store.wishlistProductIDs.append(product.id)
        }
        showWishlist()
    }

    // Pushes the launch products in one change, then makes the follow-up change while that push
    // still animates. Runs once, when the shop first appears.
    func playLaunchSteps() async {
        guard !hasPlayedLaunchSteps, !launchSteps.productIDs.isEmpty else {
            return
        }
        hasPlayedLaunchSteps = true
        let ids = launchSteps.productIDs
        router.push {
            for id in ids {
                ProductRoute(id: id)
            }
        }
        guard let followUp = launchSteps.followUp else {
            return
        }
        try? await Task.sleep(for: Self.followUpDelay)
        apply(followUp)
    }

    private func apply(_ followUp: ShopFollowUp) {
        switch followUp {
        case .pop:
            router.pop()
        case .popToRoot:
            router.popToRoot()
        case .link:
            openLinkedProduct()
        }
    }

    private func openLinkedProduct() {
        router.setPath {
            ProductRoute(id: Self.linkedProductID)
        }
    }

    private func makeShopFlow() -> some View {
        ProductListView(
            onSelect: { self.showProduct($0) },
            onSelectCollection: { self.showCollection($0) },
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

    private func makeCollectionFlow(_ collection: ProductCollection) -> some View {
        CollectionView(
            collection: collection,
            onSelect: { self.showProduct($0) }
        )
        .screenChrome(
            title: collection.name,
            kind: nil,
            trail: ProductsTrail.collection(collection)
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
            onSave: { self.save(product) },
            related: { self.makeRelatedLink(to: product.related) }
        )
        .screenChrome(
            title: product.name,
            kind: nil,
            trail: ProductsTrail.product(product, from: start)
        )
    }

    // Links to `product` with `WaypointLink`, which pushes through `router`. When a UI test passes
    // the `systemLinks` launch argument, it gets a system `NavigationLink` instead, which Waypoint
    // refuses and reports. With `missingDestination`, the link pushes the product's reviews, which
    // no screen of the stack draws, so the stack shows its missing-destination screen.
    @ViewBuilder
    private func makeRelatedLink(to product: Product) -> some View {
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
}

extension ProductsStart {
    // Names the stack's first screen in the journey lines.
    var rootName: String {
        switch self {
        case .browse:
            return "Product list"
        case .search:
            return "Search"
        }
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

    static func collection(_ collection: ProductCollection) -> [String] {
        shop + [collection.name.lowercased()]
    }

    static func product(
        _ product: Product,
        from start: ProductsStart
    ) -> [String] {
        let root = start == .browse ? shop : search
        let step = product.name.lowercased()
        return root + [step]
    }
}
