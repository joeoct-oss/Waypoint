//
//  LabDemoCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint
import WaypointCore

// Runs the Lab's view and view-model demos, presented full screen over the Lab. Each product demo
// is the small `LabShopFlow` on a Waypoint stack of its own, because stacks don't nest. Every
// product demo gets a fresh router, which this coordinator owns while the demo is up and drops once
// it has closed, so a navigator that outlives the demo has no router left. The no-router demo runs
// in a plain SwiftUI stack instead: the account stack above the Lab is a Waypoint stack, so only a
// cover, which sits outside it, has no router above its view. The cover stays plain SwiftUI until
// Waypoint's presentations are built.
//
// Conformances:
// - `Observable` (from `@Observable`), so the Lab redraws when a demo opens or closes, and when a
//   late result arrives.
@MainActor
@Observable
final class LabDemoCoordinator {
    private static let flowID = FlowID("labShop")
    private static let reviewsDelay = Duration.milliseconds(2500)

    private let navigation: NavigationConfiguration
    // `var` because `showDemo(_:)` and `dismissDemo()` change it, and `syncDemo(_:)` takes the
    // system's own dismissal.
    private(set) var presentedDemo: LabDemo?
    // `var` because `showDemo(_:)` makes a fresh router for each demo and `releaseDemo()` drops it.
    private(set) var router: StackRouter?
    // `var` because `showDemo(_:)` makes the navigator demo's model and `releaseDemo()` drops it.
    private(set) var productModel: LabProductModel?
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
        lateOutcome = nil
    }

    @ViewBuilder
    func makeDemoFlow(for demo: LabDemo) -> some View {
        if demo == .noRouter {
            makeNoRouterFlow()
        } else if let router {
            WaypointStack(flow: LabShopFlow.self, router: router) {
                makeRootFlow(for: demo)
                    .destination(LabCartRoute.self) { _ in LabCartView() }
                    .destination(LabReviewsRoute.self) { _ in LabReviewsView() }
                    .toolbar { closeItem }
            }
        }
    }

    func showDemo(_ demo: LabDemo) {
        let router = StackRouter(
            flow: Self.flowID,
            configuration: navigation
        )
        lateOutcome = nil
        productModel = makeProductModel(router)
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
    }

    func recordLateOutcome(_ outcome: NavigationOutcome) {
        lateOutcome = outcome.description
    }

    @ViewBuilder
    private func makeRootFlow(for demo: LabDemo) -> some View {
        switch demo {
        case .style(let style):
            makeStyleFlow(style)
        case .lateResult:
            makeNavigatorFlow()
        case .noRouter:
            makeNoRouterFlow()
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
// late, or a view whose navigation wrapper has no router above it.
//
// Conformances:
// - `Hashable`, so `.fullScreenCover(item:)` can tell one demo from another.
// - `Identifiable`, so `.fullScreenCover(item:)` shows one demo at a time.
enum LabDemo: Hashable, Identifiable {
    case style(NavigationStyle)
    case lateResult
    case noRouter

    var id: Self {
        self
    }
}
