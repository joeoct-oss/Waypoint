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
// main tabs, which add the product to the cart and open Cart. When the cart has products, Shop
// shows "Your cart is waiting", whose Go to cart the main tabs run as one transaction that leaves
// the cart pushed above its first product here (`ShopCartRoute`). Save needs an account, so the
// account gate asks a guest to sign in first; then the product joins the wish list, which the local
// store keeps, and a small "Saved to your wish list" sheet offers View wish list.
//
// The stack runs on Waypoint: `router`, the tab's stack router from the main tab router, owns the
// path, `ProductsFlowView` draws it with `WaypointStack`, and a swipe back comes back to the router
// by itself. The journey names the stack's first screen `Product list` or `Search`. A product page
// links to a related product with `WaypointLink`, which pushes through the same router. The router
// also presents the filters, the saved sheet and the wish list (`FilterRoute`, `SavedRoute`,
// `WishlistRoute`), each drawn on the presented router with `WaypointStack`; the sheet itself is
// still SwiftUI's, bound to the router, until Waypoint draws sheets.
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
    private let cart: ProductsCart
    // `var` because `showFilters()`, `showSaved()` and `showWishlist()` set it with the router they
    // present, and `releaseSheet()` clears both once the sheet has slid away, so it still draws
    // meanwhile.
    private(set) var presentedSheet: ProductSheet?
    // `var` for the same reason as `presentedSheet`: the presented sheet's router.
    private(set) var sheetRouter: StackRouter?
    // `var` because `playLaunchSteps()` plays them once, and the shop appears again on every tab
    // switch.
    private var hasPlayedLaunchSteps: Bool

    var issues: IssueLog {
        navigation.issues
    }

    // Whether the filters or the wish list is presented over the stack.
    var isShowingSheet: Bool {
        router.presented != nil
    }

    init(
        start: ProductsStart,
        router: StackRouter,
        store: LocalStore,
        gate: AccountGate,
        launchSteps: ShopLaunchSteps,
        navigation: ProductsNavigation,
        onAddToCart: @escaping (Product) -> Void,
        cart: ProductsCart
    ) {
        self.start = start
        self.store = store
        self.gate = gate
        self.launchSteps = launchSteps
        self.navigation = navigation
        self.onAddToCart = onAddToCart
        self.cart = cart
        self.router = router
        router.setRootName(start.rootName)
        router.register(FilterRoute.self)
        router.register(SavedRoute.self)
        router.register(WishlistRoute.self)
        presentedSheet = nil
        sheetRouter = nil
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
            makeProductFlow(
                product,
                route: route
            )
        }
    }

    // Shows the collection the banner handed over, or looks it up by id after a restore.
    @ViewBuilder
    func makeCollectionFlow(for route: CollectionRoute) -> some View {
        if let collection = route.preview ?? ProductCollection.find(id: route.id) {
            makeCollectionFlow(
                collection,
                route: route
            )
        }
    }

    // The cart Go to cart pushes above a product. Check out and Keep shopping report like the Cart
    // tab's: Check out opens checkout from the Cart tab, and Keep shopping goes back to Shop.
    func makeCartFlow() -> some View {
        CartView(
            products: cart.products(),
            onCheckout: { self.cart.onCheckout() },
            onShopMore: { self.showShop() }
        )
        .screenChrome(
            title: ShopCartRoute.screenName,
            kind: nil,
            router: router,
            route: AnyRoute(ShopCartRoute())
        )
    }

    @ViewBuilder
    func makeSheetFlow() -> some View {
        if let sheetRouter, let presentedSheet {
            WaypointStack(sheetRouter) {
                makeSheetScreen(for: presentedSheet)
            }
        }
    }

    @ViewBuilder
    private func makeSheetScreen(for sheet: ProductSheet) -> some View {
        switch sheet {
        case .filters:
            makeFiltersFlow()
        case .saved:
            makeSavedFlow()
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
        showSheet(.filters, route: FilterRoute())
    }

    func showSaved() {
        showSheet(.saved, route: SavedRoute())
    }

    // The saved sheet's View wish list: one transaction dismisses the saved sheet's flow and
    // presents the wish list, since a stack shows one presentation at a time. The router changes
    // once, so the open sheet swaps its content and grows instead of closing and opening again.
    func showWishlist() {
        router.transaction {
            $0.dismiss()
            $0.present(WishlistRoute(), style: .sheet)
        }
        takePresentedSheet(.wishlist)
    }

    func addToCart(_ product: Product) {
        onAddToCart(product)
    }

    func goToCart() {
        cart.onGoToCart()
    }

    func showShop() {
        router.popToRoot()
    }

    func save(_ product: Product) {
        gate.requireAccount(for: .save) { self.addToWishlist(product) }
    }

    func dismissSheet() {
        router.dismiss()
    }

    // Takes the system's own dismissal of the sheet, a swipe down.
    func syncSheet(_ isShowing: Bool) {
        guard !isShowing else {
            return
        }
        dismissSheet()
    }

    // Drops the sheet's router once the sheet has gone.
    func releaseSheet() {
        presentedSheet = nil
        sheetRouter = nil
    }

    private func showSheet<R: Route>(
        _ sheet: ProductSheet,
        route: R
    ) {
        router.present(route, style: .sheet)
        takePresentedSheet(sheet)
    }

    // Keeps the router the stack now presents, so the sheet draws it.
    private func takePresentedSheet(_ sheet: ProductSheet) {
        guard let presented = router.presented else {
            return
        }
        presentedSheet = sheet
        sheetRouter = presented
    }

    private func addToWishlist(_ product: Product) {
        if !store.wishlistProductIDs.contains(product.id) {
            store.wishlistProductIDs.append(product.id)
        }
        showSaved()
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
            cart: cart.products(),
            onGoToCart: { self.goToCart() },
            onSelect: { self.showProduct($0) },
            onSelectCollection: { self.showCollection($0) },
            onFilter: { self.showFilters() }
        )
        .screenChrome(
            title: MainTab.shop.title,
            kind: nil,
            router: router,
            route: nil
        )
    }

    private func makeSearchFlow() -> some View {
        SearchView(onSelect: { self.showProduct($0) })
            .screenChrome(
                title: MainTab.search.title,
                kind: nil,
                router: router,
                route: nil
            )
    }

    private func makeCollectionFlow(
        _ collection: ProductCollection,
        route: CollectionRoute
    ) -> some View {
        CollectionView(
            collection: collection,
            onSelect: { self.showProduct($0) }
        )
        .screenChrome(
            title: collection.name,
            kind: nil,
            router: router,
            route: AnyRoute(route)
        )
    }

    private func makeFiltersFlow() -> some View {
        FilterView(onApply: { self.dismissSheet() })
    }

    private func makeSavedFlow() -> some View {
        SavedView(
            onViewWishlist: { self.showWishlist() },
            onClose: { self.dismissSheet() }
        )
    }

    private func makeWishlistFlow() -> some View {
        WishlistView(
            products: Product.products(withIDs: store.wishlistProductIDs),
            onDone: { self.dismissSheet() }
        )
    }

    private func makeProductFlow(
        _ product: Product,
        route: ProductRoute
    ) -> some View {
        ProductDetailView(
            product: product,
            onAddToCart: { self.addToCart(product) },
            onSave: { self.save(product) },
            related: { self.makeRelatedLink(to: product.related) }
        )
        .screenChrome(
            title: product.name,
            kind: nil,
            router: router,
            route: AnyRoute(route)
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
