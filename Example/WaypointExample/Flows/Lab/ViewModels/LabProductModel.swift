//
//  LabProductModel.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import WaypointCore

// The demo product's view model. It imports only `WaypointCore`, never SwiftUI, and holds no text
// or layout: the view turns its state into words. It holds a `FlowNavigator<LabShopFlow>`, so it
// can only push the demo flow's routes, and it can be tested with a real router and no screen.
// Reviews load slowly on purpose. If the flow is gone when they arrive, the navigator holds no
// router any more, the push returns `.ignored`, and the model reports the outcome instead of
// moving another screen.
//
// Conformances:
// - `Observable` (from `@Observable`), so the product redraws while reviews load.
@Observable
final class LabProductModel {
    private let navigation: FlowNavigator<LabShopFlow>
    private let reviewsDelay: Duration
    private let onLateOutcome: (NavigationOutcome) -> Void
    // `var` because `loadReviews()` sets it while the reviews load.
    private(set) var isLoadingReviews: Bool
    // `var` because `showReviews()` keeps what its push did, while the flow is still there.
    private(set) var reviewsOutcome: NavigationOutcome?

    init(
        navigation: FlowNavigator<LabShopFlow>,
        reviewsDelay: Duration,
        onLateOutcome: @escaping (NavigationOutcome) -> Void
    ) {
        self.navigation = navigation
        self.reviewsDelay = reviewsDelay
        self.onLateOutcome = onLateOutcome
        isLoadingReviews = false
        reviewsOutcome = nil
    }

    func buy() {
        navigation.push(LabCartRoute())
    }

    func loadReviews() {
        isLoadingReviews = true
        reviewsOutcome = nil
        Task {
            try? await Task.sleep(for: reviewsDelay)
            showReviews()
        }
    }

    private func showReviews() {
        isLoadingReviews = false
        let outcome = navigation.push(LabReviewsRoute())
        if navigation.isActive {
            reviewsOutcome = outcome
        } else {
            onLateOutcome(outcome)
        }
    }
}
