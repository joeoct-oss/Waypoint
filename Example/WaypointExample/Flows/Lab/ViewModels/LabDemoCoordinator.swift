//
//  LabDemoCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Runs the Lab's demos, presented full screen over the Lab: the view and view-model demos, and the
// Detail push flow, which `DetailPushCoordinator` runs. Each product demo is the small
// `LabShopFlow` on a Waypoint stack of its own, because stacks don't nest, and Detail push is
// `DetailPushFlow` on another, Tabs is `TabsDemoCoordinator`'s tab container, and Sheet is
// `SheetDemoCoordinator`'s stack with the sheets and covers it presents. Detail push's coordinator
// makes its own router, which Waypoint drops once this coordinator lets it go. Every other
// product demo gets a fresh router, which this coordinator owns while the demo is up and drops once
// it has closed, so a navigator that outlives the demo has no router left. The no-router demo runs
// in a plain SwiftUI stack instead: the account stack above the Lab is a Waypoint stack, so only a
// cover, which sits outside it, has no router above its view. The cover stays plain SwiftUI until
// Waypoint's presentations are built.
//
// Conformances:
// - `Observable` (from `@Observable`), so the Lab redraws when a demo opens or closes, and when a
//   late result arrives.
@Observable
final class LabDemoCoordinator {
    private static let shopFlowID = FlowID("labShop")
    private static let reviewsDelay = Duration.milliseconds(2500)

    private let navigation: NavigationConfiguration
    // `var` because `showDemo(_:)` and `dismissDemo()` change it, and `syncDemo(_:)` takes the
    // system's own dismissal.
    private(set) var presentedDemo: LabDemo?
    // `var` because `showDemo(_:)` makes a fresh router for each demo and `releaseDemo()` drops it.
    private(set) var router: StackRouter?
    // `var` because `showDemo(_:)` makes the navigator demo's model and `releaseDemo()` drops it.
    private(set) var productModel: LabProductModel?
    // `var` because `showDemo(_:)` makes the Detail push coordinator and `releaseDemo()` drops it.
    private(set) var detailPush: DetailPushCoordinator?
    // `var` because `showDemo(_:)` makes the Tabs story's coordinator and `releaseDemo()` drops it.
    private(set) var tabsDemo: TabsDemoCoordinator?
    // `var` because `showDemo(_:)` makes the Sheet story's coordinator and `releaseDemo()` drops
    // it.
    private(set) var sheetDemo: SheetDemoCoordinator?
    // `var` because `recordLateOutcome(_:)` keeps the newest result a closed demo's model reported.
    private(set) var lateOutcome: String?

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { self.dismissDemo() }
                .accessibilityIdentifier(Identifiers.labDemoClose)
        }
    }

    init(navigation: NavigationConfiguration) {
        self.navigation = navigation
        presentedDemo = nil
        router = nil
        productModel = nil
        detailPush = nil
        tabsDemo = nil
        sheetDemo = nil
        lateOutcome = nil
    }

    @ViewBuilder
    func makeDemoFlow(for demo: LabDemo) -> some View {
        switch demo {
        case .noRouter:
            makeNoRouterFlow()
        case .detailPush:
            makeDetailPushFlow()
        case .tabs:
            makeTabsFlow()
        case .sheet:
            makeSheetFlow()
        case .style, .lateResult:
            makeShopFlow(for: demo)
        }
    }

    // Detail push, Tabs and Sheet make their own routers, so they get no stack router here and no
    // product model.
    func showDemo(_ demo: LabDemo) {
        let ownsRouter = demo == .detailPush || demo == .tabs || demo == .sheet
        let router = ownsRouter ? nil : makeRouter()
        lateOutcome = nil
        detailPush = demo == .detailPush ? DetailPushCoordinator(navigation: navigation) : nil
        tabsDemo = demo == .tabs ? makeTabsDemo() : nil
        sheetDemo = demo == .sheet ? makeSheetDemo() : nil
        productModel = router.map { makeProductModel($0) }
        self.router = router
        presentedDemo = demo
    }

    func dismissDemo() {
        presentedDemo = nil
    }

    func syncDemo(_ demo: LabDemo?) {
        presentedDemo = demo
    }

    // Drops the closed demo's router and model, once the cover has gone.
    func releaseDemo() {
        router = nil
        productModel = nil
        detailPush = nil
        tabsDemo = nil
        sheetDemo = nil
    }

    func recordLateOutcome(_ outcome: NavigationOutcome) {
        lateOutcome = outcome.description
    }

    @ViewBuilder
    private func makeShopFlow(for demo: LabDemo) -> some View {
        if let router {
            WaypointStack(flow: LabShopFlow.self, router: router) {
                makeRootFlow(for: demo)
                    .destination(LabCartRoute.self) { _ in LabCartView() }
                    .destination(LabReviewsRoute.self) { _ in LabReviewsView() }
                    .toolbar { closeItem }
            }
        }
    }

    // The shop list on the flow's own stack, with the recovered toast over it.
    @ViewBuilder
    private func makeDetailPushFlow() -> some View {
        if let detailPush {
            WaypointStack(flow: DetailPushFlow.self, router: detailPush.router) {
                detailPush.makeListFlow()
                    .destination(DetailProductRoute.self) { detailPush.makeProductFlow($0) }
                    .destination(DetailCartRoute.self) { detailPush.makeCartFlow($0) }
                    .toolbar { closeItem }
            }
            .overlay(alignment: .bottom) { makeToast(for: detailPush.toast) }
            .animation(.default, value: detailPush.toast)
        }
    }

    // The Tabs story's tab container; each tab has Close.
    @ViewBuilder
    private func makeTabsFlow() -> some View {
        if let tabsDemo {
            TabsDemoFlowView(demo: tabsDemo)
        }
    }

    // The Sheet story's stack, with the sheets and covers it presents.
    @ViewBuilder
    private func makeSheetFlow() -> some View {
        if let sheetDemo {
            SheetDemoStack(
                demo: sheetDemo,
                router: sheetDemo.router,
                level: nil
            )
        }
    }

    private func makeSheetDemo() -> SheetDemoCoordinator {
        SheetDemoCoordinator(
            navigation: navigation,
            onClose: { self.dismissDemo() }
        )
    }

    private func makeTabsDemo() -> TabsDemoCoordinator {
        TabsDemoCoordinator(
            navigation: navigation,
            onClose: { self.dismissDemo() }
        )
    }

    @ViewBuilder
    private func makeToast(for content: RecoveredToastContent?) -> some View {
        if let content {
            RecoveredToast(content: content)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // Only the shop demos reach here: the no-router demo, Detail push, Tabs and Sheet draw their
    // own stacks in `makeDemoFlow(for:)`.
    @ViewBuilder
    private func makeRootFlow(for demo: LabDemo) -> some View {
        switch demo {
        case .style(let style):
            makeStyleFlow(style)
        case .lateResult:
            makeNavigatorFlow()
        case .noRouter, .detailPush, .tabs, .sheet:
            EmptyView()
        }
    }

    // A plain SwiftUI stack, so the view's `@StackNavigation` finds no Waypoint stack above it.
    private func makeNoRouterFlow() -> some View {
        NavigationStack {
            NoRouterView()
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
        OutputsProductView(onBuy: { self.showCart() })
            .navigationTitle(LabProductContent.product.name)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func makeNavigatorFlow() -> some View {
        if let productModel {
            NavigatorProductView(model: productModel)
                .navigationTitle(LabProductContent.product.name)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func makeWrappersFlow() -> some View {
        WrapperProductView()
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
        LabProductModel(
            navigation: router.navigator(for: LabShopFlow.self),
            reviewsDelay: Self.reviewsDelay,
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
enum LabDemo: Hashable, Identifiable {
    case style(NavigationStyle)
    case lateResult
    case noRouter
    case detailPush
    case tabs
    case sheet

    var id: Self {
        self
    }
}
