//
//  DetailPushCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import ExampleNavigation
import ExampleStore
import SwiftUI
import Waypoint

// Runs the Lab's Detail push flow (TB-02 and TB-03 on the design canvas) on its own stack router:
// the shop list at the root, a product pushed from a row, and the cart pushed by Add to cart. The
// product's Back to cart banner pops to a cart that is usually not in the stack, so the call
// recovers with `.popToRoot`. In debug builds the recovered outcome shows a toast with its one-line
// description; release builds stay quiet, as the event log and the console still have the line.
// The product's Write a review pushes `DetailReviewCoordinator`'s flow on this stack, and the
// product then shows the stars it finished with.
//
// It stores no router: `StackCoordinator` makes one with `makeRouter()` the first time it is read,
// names it after this coordinator, roots it at the shop tab's name, registers its destinations, and
// drops it once the Lab lets this coordinator go. It draws itself: the Lab shows its `view`.
//
// Conformances:
// - `StackCoordinator`, so Waypoint makes, names and keeps its router, and draws its screens.
// - `Observable` (from `@Observable`), so the demo redraws when a toast appears or goes.
@Observable
final class DetailPushCoordinator: StackCoordinator {
    private static let flowID = FlowID("detailPush")
    private static let toastDuration = Duration.seconds(4)
    private static let missingCartTitle = "Cart wasn't in the stack"

    private let factory: LabFactory
    private let navigation: NavigationConfiguration
    private let onClose: () -> Void
    // `var` because `backToCart()` shows a toast for a recovered pop, and the toast's timer hides
    // it.
    private(set) var toast: RecoveredToastContent?
    // `var` because each toast replaces the timer of the one before it.
    private var toastTimer: Task<Void, Never>?
    // `var` because the review flow finishes with the stars posted for each product. Only
    // `reviewEnded(_:for:)` changes it.
    private(set) var postedReviews: [Int: Int]

    var rootName: String {
        MainTab.shop.title
    }

    var root: some View {
        factory.makeDetailPushList(
            onSelect: { self.showProduct($0) },
            onClose: { self.close() }
        )
        .screenChrome(
            title: "Shop",
            kind: .swiftUI,
            router: router,
            route: nil
        )
    }

    var destinations: some Destinations {
        Destination(DetailProductRoute.self) { self.makeProductScreen($0) }
        Destination(DetailCartRoute.self) { self.makeCartScreen($0) }
    }

    // `LabFactory` makes it, and builds its screens and the review flow.
    init(
        factory: LabFactory,
        navigation: NavigationConfiguration,
        onClose: @escaping () -> Void
    ) {
        self.factory = factory
        self.navigation = navigation
        self.onClose = onClose
        toast = nil
        toastTimer = nil
        postedReviews = [:]
    }

    func makeRouter() -> StackRouter {
        let router = StackRouter(flow: Self.flowID, configuration: navigation)
        router.declareFlow(DetailPushFlow.self)
        return router
    }

    @ViewBuilder
    func makeProductScreen(_ route: DetailProductRoute) -> some View {
        let screen = factory.makeDetailPushProduct(
            for: route,
            postedReview: { self.postedReviews[$0.id] },
            onAddToCart: { self.showCart(for: $0) },
            onBackToCart: { self.backToCart() },
            onWriteReview: { self.writeReview(for: $0) }
        )
        if let screen {
            screen.screenChrome(
                title: screen.product.name,
                kind: .swiftUI,
                router: router,
                route: AnyRoute(route)
            )
        }
    }

    @ViewBuilder
    func makeCartScreen(_ route: DetailCartRoute) -> some View {
        if let screen = factory.makeDetailPushCart(for: route) {
            screen.screenChrome(
                title: "Cart",
                kind: .swiftUI,
                router: router,
                route: AnyRoute(route)
            )
        }
    }

    func close() {
        onClose()
    }

    func showProduct(_ product: Product) {
        router.push(DetailProductRoute(productID: product.id))
    }

    func showCart(for product: Product) {
        router.push(DetailCartRoute(productID: product.id))
    }

    // Pushes the review flow above the product; its result comes back once.
    func writeReview(for product: Product) {
        router.push(factory.makeDetailReview(for: product)) { result in
            self.reviewEnded(result, for: product)
        }
    }

    // Keeps the stars a posted review gave; a review left with Back changes nothing.
    func reviewEnded(_ result: FlowResult<Int>, for product: Product) {
        guard case .finished(let rating) = result else {
            return
        }
        postedReviews[product.id] = rating
    }

    // Pops to the cart, or back to the shop list when the cart isn't in the stack.
    func backToCart() {
        let outcome = router.popTo(DetailCartRoute.self, else: .popToRoot)
        showToast(for: outcome, title: Self.missingCartTitle)
    }

    // Debug builds only: a recovered call shows its one-line description for a few seconds.
    private func showToast(for outcome: NavigationOutcome, title: String) {
        #if DEBUG
        guard outcome.recoveredIssue != nil else {
            return
        }
        toast = RecoveredToastContent(title: title, outcome: outcome.description)
        toastTimer?.cancel()
        toastTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.toastDuration)
            guard !Task.isCancelled else {
                return
            }
            self?.hideToast()
        }
        #endif
    }

    private func hideToast() {
        toast = nil
    }
}
