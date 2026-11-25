//
//  LabFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Builds the Navigation Lab from `LabDependencies`: the coordinator that runs its demos, the Detail
// push, Tabs and Sheet stories' coordinators and their child coordinators, each on the Lab's
// navigation configuration, and every Lab screen the Account tab and those coordinators show. The
// coordinators pass in what each screen reports, so navigation stays in the coordinators.
struct LabFactory {
    private let dependencies: LabDependencies

    init(dependencies: LabDependencies) {
        self.dependencies = dependencies
    }

    // The Lab's demos. `reviewsDelay` is how long the demo reviews take to load; `nil` keeps the
    // usual delay.
    func makeDemos(reviewsDelay: Duration? = nil) -> LabDemoCoordinator {
        LabDemoCoordinator(
            factory: self,
            navigation: dependencies.navigation,
            reviewsDelay: reviewsDelay
        )
    }

    func makeDetailPush(onClose: @escaping () -> Void) -> DetailPushCoordinator {
        DetailPushCoordinator(
            factory: self,
            navigation: dependencies.navigation,
            onClose: onClose
        )
    }

    // Write a review for `product`, the child flow Detail push pushes on its own stack.
    func makeDetailReview(for product: Product) -> DetailReviewCoordinator {
        DetailReviewCoordinator(
            product: product,
            factory: self
        )
    }

    func makeTabsDemo(onClose: @escaping () -> Void) -> TabsDemoCoordinator {
        TabsDemoCoordinator(
            factory: self,
            navigation: dependencies.navigation,
            onClose: onClose
        )
    }

    // The coordinator of `tab` in the Tabs story, which holds `demo` without keeping it alive.
    func makeTabsDemoTab(
        _ tab: DemoTab,
        demo: TabsDemoCoordinator
    ) -> TabsDemoTabCoordinator {
        TabsDemoTabCoordinator(
            tab: tab,
            demo: demo,
            factory: self
        )
    }

    func makeSheetDemo(onClose: @escaping () -> Void) -> SheetDemoCoordinator {
        SheetDemoCoordinator(
            navigation: dependencies.navigation,
            onClose: onClose
        )
    }

    func makeSwiftUIBranch(onSelect: @escaping (FlowEntry) -> Void) -> SwiftUIBranchView {
        SwiftUIBranchView(onSelect: onSelect)
    }

    func makeUIKitBranch(onSelect: @escaping (FlowEntry) -> Void) -> UIKitBranchView {
        UIKitBranchView(onSelect: onSelect)
    }

    func makePlaceholder(_ entry: FlowEntry) -> PlaceholderView {
        PlaceholderView(entry: entry)
    }

    func makePlaceholderController(_ entry: FlowEntry) -> PlaceholderControllerView {
        PlaceholderControllerView(entry: entry)
    }

    func makeNavigationStyle(onTry: @escaping (NavigationStyle) -> Void) -> NavigationStyleView {
        NavigationStyleView(onTry: onTry)
    }

    func makeLateResult(
        demos: LabDemoCoordinator,
        onOpen: @escaping () -> Void
    ) -> LateResultView {
        LateResultView(
            demos: demos,
            onOpen: onOpen
        )
    }

    func makeNoRouter() -> NoRouterView {
        NoRouterView()
    }

    func makePreviewHelp() -> PreviewHelpView {
        PreviewHelpView()
    }

    // The navigator demo's model on `router`, which declares the demo shop on that stack.
    func makeProductModel(
        on router: StackRouter,
        reviewsDelay: Duration,
        onLateOutcome: @escaping (NavigationOutcome) -> Void
    ) -> LabProductModel {
        LabProductModel(
            navigation: router.navigator(for: LabShopFlow.self),
            reviewsDelay: reviewsDelay,
            onLateOutcome: onLateOutcome
        )
    }

    func makeOutputsProduct(onBuy: @escaping () -> Void) -> OutputsProductView {
        OutputsProductView(onBuy: onBuy)
    }

    func makeNavigatorProduct(model: LabProductModel) -> NavigatorProductView {
        NavigatorProductView(model: model)
    }

    func makeWrapperProduct() -> WrapperProductView {
        WrapperProductView()
    }

    func makeLabCart() -> LabCartView {
        LabCartView()
    }

    func makeLabReviews() -> LabReviewsView {
        LabReviewsView()
    }

    func makeTabsDemoFlow(_ demo: TabsDemoCoordinator) -> TabsDemoFlowView {
        TabsDemoFlowView(demo: demo)
    }

    // One tab's screen of the Tabs story.
    func makeTabsDemoScreen(
        tab: DemoTab,
        selection: DemoTab,
        showsAllTabs: Bool,
        onChangeTabs: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) -> TabsDemoView {
        TabsDemoView(
            tab: tab,
            selection: selection,
            showsAllTabs: showsAllTabs,
            onChangeTabs: onChangeTabs,
            onClose: onClose
        )
    }

    // The Sheet story's stack, with the sheets and covers it presents.
    func makeSheetDemoFlow(_ demo: SheetDemoCoordinator) -> SheetDemoStack {
        SheetDemoStack(
            demo: demo,
            router: demo.router,
            level: nil
        )
    }

    func makeDetailPushList(
        onSelect: @escaping (Product) -> Void,
        onClose: @escaping () -> Void
    ) -> DetailPushListView {
        DetailPushListView(
            products: dependencies.catalog.products,
            onSelect: onSelect,
            onClose: onClose
        )
    }

    // The product with the route's id, or `nil` when the catalog has none. `postedReview` is the
    // stars a posted review gave it.
    func makeDetailPushProduct(
        for route: DetailProductRoute,
        postedReview: (Product) -> Int?,
        onAddToCart: @escaping (Product) -> Void,
        onBackToCart: @escaping () -> Void,
        onWriteReview: @escaping (Product) -> Void
    ) -> DetailPushProductView? {
        guard let product = dependencies.catalog.product(id: route.productID) else {
            return nil
        }
        return DetailPushProductView(
            product: product,
            postedReview: postedReview(product),
            onAddToCart: { onAddToCart(product) },
            onBackToCart: onBackToCart,
            onWriteReview: { onWriteReview(product) }
        )
    }

    // The cart of the route's product, or `nil` when the catalog has none.
    func makeDetailPushCart(for route: DetailCartRoute) -> DetailPushCartView? {
        guard let product = dependencies.catalog.product(id: route.productID) else {
            return nil
        }
        return DetailPushCartView(product: product)
    }

    func makeDetailReviewRating(onRate: @escaping (Int) -> Void) -> DetailReviewRatingView {
        DetailReviewRatingView(onRate: onRate)
    }

    func makeDetailReviewNote(
        rating: Int,
        onPost: @escaping () -> Void
    ) -> DetailReviewNoteView {
        DetailReviewNoteView(
            rating: rating,
            onPost: onPost
        )
    }
}
