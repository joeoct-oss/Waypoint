//
//  LabDemoCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI
import Waypoint

// Runs the Lab's demos, presented full screen over the Lab: the view and view-model demos, and the
// Detail push flow, which `DetailPushCoordinator` runs. Each product demo is the small
// `LabShopFlow` on a Waypoint stack of its own, because stacks don't nest, and Detail push is
// `DetailPushFlow`, drawn by its coordinator's own `view`. Tabs is `TabsDemoCoordinator`'s tab
// container, and Sheet is `SheetDemoCoordinator`'s stack with the sheets and covers it presents.
// Detail push's coordinator makes its own router, which Waypoint drops once this coordinator lets
// it go. Every other product demo gets a fresh router, which this coordinator owns while the demo
// is up and drops once it has closed, so a navigator that outlives the demo has no router left.
// The no-router demo runs in a plain SwiftUI stack instead: the account stack above the Lab is a
// Waypoint stack, so only a cover, which sits outside it, has no router above its view. The cover
// stays plain SwiftUI until Waypoint's presentations are built.
//
// Conformances:
// - `Observable` (from `@Observable`), so the Lab redraws when a demo opens or closes, and when a
//   late result arrives.
@Observable
package final class LabDemoCoordinator {
    private static let shopFlowID = FlowID("labShop")
    private static let defaultReviewsDelay = Duration.milliseconds(2500)

    private let factory: LabFactory
    private let navigation: NavigationConfiguration
    private let reviewsDelay: Duration
    // `var` because `showDemo(_:)` and `dismissDemo()` change it, and `syncDemo(_:)` takes the
    // system's own dismissal.
    package private(set) var presentedDemo: LabDemo?
    // `var` because `showDemo(_:)` makes a fresh router for each demo and `releaseDemo()` drops it.
    package private(set) var router: StackRouter?
    // `var` because `showDemo(_:)` makes the navigator demo's model and `releaseDemo()` drops it.
    package private(set) var productModel: LabProductModel?
    // `var` because `showDemo(_:)` makes the Detail push coordinator and `releaseDemo()` drops it.
    package private(set) var detailPush: DetailPushCoordinator?
    // `var` because `showDemo(_:)` makes the Tabs story's coordinator and `releaseDemo()` drops it.
    package private(set) var tabsDemo: TabsDemoCoordinator?
    // `var` because `showDemo(_:)` makes the Sheet story's coordinator and `releaseDemo()` drops
    // it.
    package private(set) var sheetDemo: SheetDemoCoordinator?
    // `var` because `recordLateOutcome(_:)` keeps the newest result a closed demo's model reported.
    package private(set) var lateOutcome: String?

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { self.dismissDemo() }
                .accessibilityIdentifier(Identifiers.labDemoClose)
        }
    }

    // `LabFactory` makes it. `reviewsDelay` is how long the demo reviews take to load; `nil` keeps
    // the usual delay.
    package init(
        factory: LabFactory,
        navigation: NavigationConfiguration,
        reviewsDelay: Duration?
    ) {
        self.factory = factory
        self.navigation = navigation
        self.reviewsDelay = reviewsDelay ?? Self.defaultReviewsDelay
        presentedDemo = nil
        router = nil
        productModel = nil
        detailPush = nil
        tabsDemo = nil
        sheetDemo = nil
        lateOutcome = nil
    }

    @ViewBuilder
    package func makeDemoFlow(for demo: LabDemo) -> some View {
        switch demo {
        case .noRouter:
            makeNoRouterFlow()
        case .detailPush:
            makeDetailPushFlow()
        case .tabs:
            makeTabsFlow()
        case .sheet:
            makeSheetFlow()
        case .style(let style):
            makeShopFlow { self.makeStyleFlow(style) }
        case .lateResult:
            makeShopFlow { self.makeNavigatorFlow() }
        }
    }

    // Detail push, Tabs and Sheet make their own routers, so they get no stack router here and no
    // product model.
    package func showDemo(_ demo: LabDemo) {
        let ownsRouter = demo == .detailPush || demo == .tabs || demo == .sheet
        let router = ownsRouter ? nil : makeRouter()
        lateOutcome = nil
        detailPush = demo == .detailPush ? makeDetailPushDemo() : nil
        tabsDemo = demo == .tabs ? makeTabsDemo() : nil
        sheetDemo = demo == .sheet ? makeSheetDemo() : nil
        productModel = router.map { makeProductModel($0) }
        self.router = router
        presentedDemo = demo
    }

    package func dismissDemo() {
        presentedDemo = nil
    }

    package func syncDemo(_ demo: LabDemo?) {
        presentedDemo = demo
    }

    // Drops the closed demo's router and model, once the cover has gone.
    package func releaseDemo() {
        router = nil
        productModel = nil
        detailPush = nil
        tabsDemo = nil
        sheetDemo = nil
    }

    package func recordLateOutcome(_ outcome: NavigationOutcome) {
        lateOutcome = outcome.description
    }

    // A product demo: `root` on the demo's own stack, with Close.
    @ViewBuilder
    private func makeShopFlow<Root: View>(@ViewBuilder root: () -> Root) -> some View {
        if let router {
            WaypointStack(flow: LabShopFlow.self, router: router) {
                root()
                    .destination(LabCartRoute.self) { _ in self.factory.makeLabCart() }
                    .destination(LabReviewsRoute.self) { _ in self.factory.makeLabReviews() }
                    .toolbar { closeItem }
            }
        }
    }

    // The shop list on the flow's own stack, with the recovered toast over it.
    @ViewBuilder
    private func makeDetailPushFlow() -> some View {
        if let detailPush {
            detailPush.view
                .overlay(alignment: .bottom) { makeToast(for: detailPush.toast) }
                .animation(.default, value: detailPush.toast)
        }
    }

    // The Tabs story's tab container; each tab has Close.
    @ViewBuilder
    private func makeTabsFlow() -> some View {
        if let tabsDemo {
            factory.makeTabsDemoFlow(tabsDemo)
        }
    }

    // The Sheet story's stack, with the sheets and covers it presents.
    @ViewBuilder
    private func makeSheetFlow() -> some View {
        if let sheetDemo {
            factory.makeSheetDemoFlow(sheetDemo)
        }
    }

    private func makeDetailPushDemo() -> DetailPushCoordinator {
        factory.makeDetailPush(onClose: { self.dismissDemo() })
    }

    private func makeSheetDemo() -> SheetDemoCoordinator {
        factory.makeSheetDemo(onClose: { self.dismissDemo() })
    }

    private func makeTabsDemo() -> TabsDemoCoordinator {
        factory.makeTabsDemo(onClose: { self.dismissDemo() })
    }

    @ViewBuilder
    private func makeToast(for content: RecoveredToastContent?) -> some View {
        if let content {
            RecoveredToast(content: content)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // A plain SwiftUI stack, so the view's `@StackNavigation` finds no Waypoint stack above it.
    private func makeNoRouterFlow() -> some View {
        NavigationStack {
            factory.makeNoRouter()
                .navigationTitle(ViewModelStory.noRouter.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { closeItem }
        }
    }

    @ViewBuilder
    private func makeStyleFlow(_ style: NavigationStyle) -> some View {
        switch style {
        case .outputs:
            makeOutputsFlow()
        case .navigator:
            makeNavigatorFlow()
        case .wrappers:
            makeWrappersFlow()
        }
    }

    private func makeOutputsFlow() -> some View {
        factory.makeOutputsProduct(onBuy: { self.showCart() })
            .navigationTitle(LabProductContent.product.name)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func makeNavigatorFlow() -> some View {
        if let productModel {
            factory.makeNavigatorProduct(model: productModel)
                .navigationTitle(LabProductContent.product.name)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func makeWrappersFlow() -> some View {
        factory.makeWrapperProduct()
            .navigationTitle(LabProductContent.product.name)
            .navigationBarTitleDisplayMode(.inline)
    }

    private func makeRouter() -> StackRouter {
        StackRouter(
            flow: Self.shopFlowID,
            configuration: navigation
        )
    }

    private func makeProductModel(_ router: StackRouter) -> LabProductModel {
        factory.makeProductModel(
            on: router,
            reviewsDelay: reviewsDelay,
            onLateOutcome: { self.recordLateOutcome($0) }
        )
    }

    private func showCart() {
        router?.push(LabCartRoute())
    }
}

// A demo the Lab presents: the product in one navigation style, the product whose reviews arrive
// late, a view whose navigation wrapper has no router above it, the Detail push flow, or the Tabs
// story.
//
// Conformances:
// - `Hashable`, so `.fullScreenCover(item:)` can tell one demo from another.
// - `Identifiable`, so `.fullScreenCover(item:)` shows one demo at a time.
package enum LabDemo: Hashable, Identifiable {
    case style(NavigationStyle)
    case lateResult
    case noRouter
    case detailPush
    case tabs
    case sheet

    package var id: Self {
        self
    }
}
