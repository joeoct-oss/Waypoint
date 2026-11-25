//
//  LabFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleStore
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

    // A branch's list of entries: SwiftUI's in SwiftUI, UIKit's in a view controller.
    @ViewBuilder
    func makeBranch(
        _ branch: Branch,
        onSelect: @escaping (FlowEntry) -> Void
    ) -> some View {
        switch branch {
        case .swiftUI:
            SwiftUIBranchView(onSelect: onSelect)
        case .uiKit:
            UIKitBranchView(onSelect: onSelect)
        }
    }

    // The placeholder an entry that isn't built yet shows, of the entry's kind.
    @ViewBuilder
    func makePlaceholder(for entry: FlowEntry) -> some View {
        switch entry.kind {
        case .swiftUI:
            PlaceholderView(entry: entry)
        case .uiKit:
            PlaceholderControllerView(entry: entry)
        }
    }

    // A Views and view models story's screen. Navigation style's Try reports `onTry`, and the late
    // result story's Open reports `onOpenLateResult`. The no-router story is reached here only
    // when the account stack is above it; the Lab opens it full screen instead.
    @ViewBuilder
    func makeStory(
        _ story: ViewModelStory,
        demos: LabDemoCoordinator,
        onTry: @escaping (NavigationStyle) -> Void,
        onOpenLateResult: @escaping () -> Void
    ) -> some View {
        switch story {
        case .style:
            NavigationStyleView(onTry: onTry)
        case .lateResult:
            LateResultView(
                demos: demos,
                onOpen: onOpenLateResult
            )
        case .noRouter:
            makeNoRouter()
        case .preview:
            PreviewHelpView()
        }
    }

    func makeNoRouter() -> NoRouterView {
        NoRouterView()
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
