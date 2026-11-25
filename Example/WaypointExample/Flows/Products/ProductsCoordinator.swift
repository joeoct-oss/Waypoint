//
//  ProductsCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// A stack of products: the shop or search at the root, a collection from Shop's banner and a
// product pushed above it, with the filters and the wish list as sheets. Add to cart reports to the
// main tabs, which add the product to the cart and open Cart. When the cart has products, Shop
// shows "Your cart is waiting", whose Go to cart the main tabs run as one transaction that leaves
// the cart pushed above its first product here (`ShopCartRoute`). Save needs an account, so the
// account gate asks a guest to sign in first; then the product joins the wish list, which the local
// store keeps, and a small "Saved to your wish list" sheet offers View wish list. Shop's Wish list
// button opens the wish list as a sheet for anyone; its "You may also like" Save asks a guest to
// sign in over the wish list, two sheets deep, and Done on Signed in closes both in one change
// (`dismissAll`). The wish list's Done closes its own flow (`dismissFlow`), and the saved sheet's
// Close does the same from the view (`@DismissFlow`).
//
// The stack runs on Waypoint: `router`, which Waypoint makes and the main tabs make the one stack
// every tab shares, owns the path. `MainTabView` draws it with `WaypointStack` around the tabs and
// asks the selected tab's coordinator for each pushed screen, and a swipe back comes back to the
// router by itself. `root` draws the tab's root, and `ProductsSheet` its sheets. A product page
// links to a related product with `WaypointLink`, which pushes through the same router, and a
// search result pushes from `SearchModel`, a view model holding the stack's navigator scoped to
// `ShopFlow`, which the stack declares. The router also presents the filters, the saved sheet and
// the wish list (`FilterRoute`, `SavedRoute`, `WishlistRoute`), each drawn on the presented router
// with `WaypointStack`; the sheet itself is still SwiftUI's, bound to the router, until Waypoint
// draws sheets.
//
// Conformances:
// - `StackCoordinator`, so Waypoint makes its router and the main tabs make it the shared stack.
// - `Observable` (from `@Observable`), so `ProductsSheet` redraws when the sheet changes.
@Observable
final class ProductsCoordinator: StackCoordinator {
    private static let followUpDelay = Duration.milliseconds(150)
    private static let linkedProductID = 4

    private let start: ProductsStart
    private let store: LocalStore
    private let gate: any SheetAccountGating
    private let factory: ProductsFactory
    private let launchSteps: ShopLaunchSteps
    private let navigation: ProductsNavigation
    private let onAddToCart: (Product) -> Void
    private let cart: ProductsCart
    // `var` because Search's view model is made the first time Search's root draws, on the router
    // Waypoint has made by then, and kept. Only `searchModel` changes it. Not observed, because it
    // changes while the root draws.
    @ObservationIgnored private var madeSearchModel: SearchModel?
    // `var` because `showFilters()`, `showSaved()` and `showWishlist()` set it with the router they
    // present, and `releaseSheet()` clears both once the sheet has slid away, so it still draws
    // meanwhile.
    private(set) var presentedSheet: ProductSheet?
    // `var` for the same reason as `presentedSheet`: the presented sheet's router.
    private(set) var sheetRouter: StackRouter?
    // `var` for the same reason as `presentedSheet`: the sizes the router gives the sheet.
    private(set) var sheetOptions: SheetOptions?
    // `var` because the wish list sheet and Save change it; it copies the local store, which
    // nothing observes, so the open sheet redraws.
    private(set) var wishlistProductIDs: [Int]
    // `var` because `playLaunchSteps()` plays them once, and the shop appears again on every tab
    // switch.
    private var hasPlayedLaunchSteps: Bool

    // The tab's root: Shop or Search. Shop plays the launch steps the first time it appears.
    var root: some View {
        makeRootFlow()
            .task { await self.playLaunchSteps() }
    }

    // Names the stack's first screen in the journey lines.
    var rootName: String {
        start.rootName
    }

    // Search's view model, which pushes a tapped result itself.
    private var searchModel: SearchModel {
        if let madeSearchModel {
            return madeSearchModel
        }
        let model = factory.makeSearchModel(on: router)
        madeSearchModel = model
        return model
    }

    // Whether this coordinator's filters, saved sheet or wish list is presented over the stack.
    // Shop and Search share one stack, so a presentation the other tab made doesn't count.
    var isShowingSheet: Bool {
        guard let sheetRouter else {
            return false
        }
        return router.presented === sheetRouter
    }

    init(
        start: ProductsStart,
        dependencies: ProductsDependencies,
        factory: ProductsFactory,
        launchSteps: ShopLaunchSteps,
        onAddToCart: @escaping (Product) -> Void,
        cart: ProductsCart
    ) {
        self.start = start
        store = dependencies.store
        gate = dependencies.gate
        self.factory = factory
        self.launchSteps = launchSteps
        navigation = dependencies.navigation
        self.onAddToCart = onAddToCart
        self.cart = cart
        madeSearchModel = nil
        presentedSheet = nil
        sheetRouter = nil
        sheetOptions = nil
        wishlistProductIDs = store.wishlistProductIDs
        hasPlayedLaunchSteps = false
    }

    // Registers the routes this stack pushes and presents. `MainTabView` draws the pushed screens
    // on the stack every tab shares, so the stack has no `destinations` of its own.
    func registerDestinations(on router: StackRouter) {
        router.register(ProductRoute.self)
        router.register(CollectionRoute.self)
        router.register(ShopCartRoute.self)
        router.register(FilterRoute.self)
        router.register(SavedRoute.self)
        router.register(WishlistRoute.self)
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
        if let detail = makeProductDetail(for: route) {
            detail.screenChrome(
                title: detail.product.name,
                kind: nil,
                router: router,
                route: AnyRoute(route)
            )
        }
    }

    // Shows the collection the banner handed over, or looks it up by id after a restore.
    @ViewBuilder
    func makeCollectionFlow(for route: CollectionRoute) -> some View {
        if let collection = factory.makeCollection(for: route, onSelect: { self.showProduct($0) }) {
            collection.screenChrome(
                title: collection.collection.name,
                kind: nil,
                router: router,
                route: AnyRoute(route)
            )
        }
    }

    // The product page for `route`, or `nil` when the catalog has no such product.
    private func makeProductDetail(for route: ProductRoute) -> ProductDetailView<some View>? {
        factory.makeProductDetail(
            for: route,
            onAddToCart: { self.addToCart($0) },
            onSave: { self.save($0) },
            related: { self.makeRelatedLink(to: $0.related) }
        )
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

    // The presented sheet, with the accounts flow over it when the wish list asked a guest to sign
    // in.
    @ViewBuilder
    func makeSheetFlow() -> some View {
        if let sheetRouter, let presentedSheet {
            WaypointStack(sheetRouter) {
                makeSheetScreen(for: presentedSheet)
            }
            .sheetOptions(sheetOptions)
            .sheet(
                isPresented: Binding(reading: gate.isShowingAuth(over: sheetRouter), writing: gate.syncAuth),
                onDismiss: { self.gate.finishAuth(over: sheetRouter) }
            ) {
                self.makeAuthFlow(over: sheetRouter)
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

    // Shop's Filter and Wish list, for the main tabs' navigation bar.
    func makeShopToolbar() -> ShopToolbar {
        ShopToolbar(
            onFilter: { self.showFilters() },
            onWishlist: { self.openWishlist() }
        )
    }

    func showFilters() {
        showSheet(
            .filters,
            route: FilterRoute(),
            style: AppSheets.filters
        )
    }

    func showSaved() {
        showSheet(
            .saved,
            route: SavedRoute(),
            style: AppSheets.saved
        )
    }

    // Shop's Wish list button.
    func openWishlist() {
        wishlistProductIDs = store.wishlistProductIDs
        showSheet(
            .wishlist,
            route: WishlistRoute(),
            style: AppSheets.large
        )
    }

    // The saved sheet's View wish list: one transaction dismisses the saved sheet's flow and
    // presents the wish list, since a stack shows one presentation at a time. The router changes
    // once, so the open sheet swaps its content and grows instead of closing and opening again.
    func showWishlist() {
        wishlistProductIDs = store.wishlistProductIDs
        router.transaction {
            $0.dismiss()
            $0.present(WishlistRoute(), style: AppSheets.large)
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

    // Save under "You may also like": a guest signs in over the wish list first.
    func saveFromWishlist(_ product: Product) {
        guard let sheetRouter else {
            return
        }
        gate.requireAccount(
            for: .save,
            over: sheetRouter,
            then: { self.keep(product) },
            done: { self.dismissAllSheets() }
        )
    }

    func dismissSheet() {
        router.dismiss()
    }

    // Done on Signed in: the wish list and the accounts flow over it close in one change.
    func dismissAllSheets() {
        router.dismissAll()
    }

    // The wish list's Done: the wish list's own router asks the stack that presented it to close
    // it.
    func closeWishlist() {
        sheetRouter?.dismissFlow()
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
        if let sheetRouter {
            gate.finishAuth(over: sheetRouter)
        }
        presentedSheet = nil
        sheetRouter = nil
        sheetOptions = nil
    }

    private func showSheet<R: Route>(
        _ sheet: ProductSheet,
        route: R,
        style: PresentationStyle
    ) {
        router.present(route, style: style)
        takePresentedSheet(sheet)
    }

    // Keeps the router the stack now presents, so the sheet draws it.
    private func takePresentedSheet(_ sheet: ProductSheet) {
        guard let presented = router.presented else {
            return
        }
        presentedSheet = sheet
        sheetRouter = presented
        sheetOptions = router.state.presentation.map { router.sheetOptions(for: $0) }
    }

    private func addToWishlist(_ product: Product) {
        keep(product)
        showSaved()
    }

    private func keep(_ product: Product) {
        if !store.wishlistProductIDs.contains(product.id) {
            store.wishlistProductIDs.append(product.id)
        }
        wishlistProductIDs = store.wishlistProductIDs
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
        factory.makeProductList(
            cart: cart.products(),
            onGoToCart: { self.goToCart() },
            onSelect: { self.showProduct($0) },
            onSelectCollection: { self.showCollection($0) }
        )
        .screenChrome(
            title: MainTab.shop.title,
            kind: nil,
            router: router,
            route: nil
        )
    }

    private func makeSearchFlow() -> some View {
        factory.makeSearch(model: searchModel)
            .screenChrome(
                title: MainTab.search.title,
                kind: nil,
                router: router,
                route: nil
            )
    }

    private func makeFiltersFlow() -> some View {
        factory.makeFilters(onApply: { self.dismissSheet() })
    }

    private func makeSavedFlow() -> some View {
        factory.makeSaved(onViewWishlist: { self.showWishlist() })
    }

    private func makeWishlistFlow() -> some View {
        factory.makeWishlist(
            productIDs: wishlistProductIDs,
            onSave: { self.saveFromWishlist($0) },
            onDone: { self.closeWishlist() }
        )
    }

    @ViewBuilder
    private func makeAuthFlow(over sheetRouter: StackRouter) -> some View {
        if let auth = gate.auth(over: sheetRouter) {
            AuthFlowView(auth: auth)
                .sheetOptions(gate.authSheetOptions)
        }
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
