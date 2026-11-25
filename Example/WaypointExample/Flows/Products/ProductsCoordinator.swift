//
//  ProductsCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleNavigation
import ExampleServices
import ExampleStore
import SwiftUI
import Waypoint

// A stack of products: the shop or search at the root, a collection from Shop's banner and a
// product pushed above it, with the filters and the wish list as sheets. Add to cart reports to the
// main tabs, which add the product to the cart and open Cart. When the cart has products, Shop
// shows "Your cart is waiting", whose Go to cart the main tabs run as one transaction that leaves
// the cart pushed above its first product here (`ShopCartRoute`). Save needs an account, so the
// account gate asks a guest to sign in first; then the product joins the wish list, which the local
// store keeps, and a small "Saved to your wish list" sheet offers View wish list. Shop's Wish list
// button opens the wish list, a child flow `WishlistCoordinator` runs, as a sheet for anyone; its
// "You may also like" Save asks a guest to sign in over the wish list, two sheets deep, and Done on
// Signed in closes both in one change (`dismissAll`). The wish list's Done closes its own flow
// (`dismissFlow`), and the saved sheet's Close does the same from the view (`@DismissFlow`).
//
// The stack runs on Waypoint: `router`, which Waypoint makes and the main tabs make the one stack
// every tab shares, owns the path. `MainTabView` draws it with `WaypointStack` around the tabs and
// asks the selected tab's coordinator for each pushed screen, and a swipe back comes back to the
// router by itself. `root` draws the tab's root, and `ProductsSheet` its sheets. A product page
// links to a related product with `WaypointLink`, which pushes through the same router, and a
// search result pushes from `SearchModel`, a view model holding the stack's navigator scoped to
// `ShopFlow`, which the stack declares. The router also presents the filters and the saved sheet
// (`FilterRoute`, `SavedRoute`) and the wish list's flow, each drawn on the presented router with
// `WaypointStack`; the sheet itself is still SwiftUI's, bound to the router, until Waypoint draws
// sheets.
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
    private let cart: ProductsCart
    // `var` because Search's view model is made the first time Search's root draws, on the router
    // Waypoint has made by then, and kept. Only `searchModel` changes it. Not observed, because it
    // changes while the root draws.
    @ObservationIgnored private var madeSearchModel: SearchModel?
    // The filters, the saved sheet or the wish list, which `showFilters()`, `showSaved()` and
    // `openWishlist()` keep and `releaseSheet()` drops once the sheet has slid away, so it still
    // draws meanwhile.
    let sheet: PresentedSheet<ProductSheet>
    // `var` because `showWishlist()` and `openWishlist()` set it with the flow they present, and
    // `releaseSheet()` drops it once the sheet has gone.
    private(set) var wishlist: WishlistCoordinator?
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
        sheet.isShowing(over: router)
    }

    // `ProductsFactory` makes it, and hands it the feature's dependencies.
    init(
        factory: ProductsFactory,
        start: ProductsStart,
        cart: ProductsCart
    ) {
        let dependencies = factory.dependencies
        self.start = start
        store = dependencies.store
        gate = dependencies.gate
        self.factory = factory
        launchSteps = start.launchSteps
        self.cart = cart
        madeSearchModel = nil
        sheet = PresentedSheet()
        wishlist = nil
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
            related: { self.factory.makeRelatedLink(to: $0.related) }
        )
    }

    // The cart Go to cart pushes above a product. Check out and Keep shopping report like the Cart
    // tab's: Check out opens checkout from the Cart tab, and Keep shopping goes back to Shop.
    func makeCartFlow() -> some View {
        factory.makeCart(
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
        if let sheetRouter = sheet.router, let presentedSheet = sheet.sheet {
            WaypointStack(sheetRouter) {
                makeSheetScreen(for: presentedSheet)
            }
            .sheetOptions(sheet.options)
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

    // Shop's Wish list button: starts the wish list's flow as a sheet.
    func openWishlist() {
        let wishlist = factory.makeWishlistFlow(onCloseAll: { self.dismissAllSheets() })
        let outcome = router.present(wishlist, style: AppSheets.large) { _ in }
        guard outcome.didChange else {
            return
        }
        self.wishlist = wishlist
        sheet.keep(.wishlist, presentedBy: router)
    }

    // The saved sheet's View wish list: dismisses the saved sheet's flow, then starts the wish
    // list's, since a stack shows one presentation at a time. Both happen before the sheet redraws,
    // so it swaps its content and grows instead of closing and opening again.
    func showWishlist() {
        router.dismiss()
        openWishlist()
    }

    func addToCart(_ product: Product) {
        cart.onAddToCart(product)
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

    // Done on Signed in: the wish list and the accounts flow over it close in one change.
    func dismissAllSheets() {
        router.dismissAll()
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
        if let sheetRouter = sheet.router {
            gate.finishAuth(over: sheetRouter)
        }
        sheet.release()
        wishlist = nil
    }

    private func showSheet<R: Route>(
        _ sheet: ProductSheet,
        route: R,
        style: PresentationStyle
    ) {
        router.present(route, style: style)
        self.sheet.keep(sheet, presentedBy: router)
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

    @ViewBuilder
    private func makeWishlistFlow() -> some View {
        if let wishlist {
            wishlist.root
        }
    }

    @ViewBuilder
    private func makeAuthFlow(over sheetRouter: StackRouter) -> some View {
        if let authFlow = gate.authFlow(over: sheetRouter) {
            authFlow
                .sheetOptions(gate.authSheetOptions)
        }
    }
}
