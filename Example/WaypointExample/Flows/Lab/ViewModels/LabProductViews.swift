//
//  LabProductViews.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// The demo product in the outputs style: the view knows nothing from Waypoint and reports Add to
// cart, and the coordinator that made it pushes.
package struct OutputsProductView: View {
    package let onBuy: () -> Void

    package var body: some View {
        LabProductContent(
            note: NavigationStyle.outputs.pusher,
            detail: NavigationStyle.outputs.explanation,
            isLoadingReviews: false,
            onReviews: nil,
            onAddToCart: onBuy
        )
    }
}

// The demo product in the injected-navigator style: the view hands each tap to its model, which
// navigates with the navigator the stack's destination gave it.
package struct NavigatorProductView: View {
    package let model: LabProductModel

    package var body: some View {
        LabProductContent(
            note: NavigationStyle.navigator.pusher,
            detail: detail,
            isLoadingReviews: model.isLoadingReviews,
            onReviews: { model.loadReviews() },
            onAddToCart: { model.buy() }
        )
    }

    // What the model is doing, in words. The model keeps state; the view says it.
    private var detail: String {
        if model.isLoadingReviews {
            return "Loading reviews. The model pushes them when they arrive."
        }
        guard let outcome = model.reviewsOutcome else {
            return NavigationStyle.navigator.explanation
        }
        return "Reviews pushed: \(outcome.description)"
    }
}

// The demo product in the property-wrapper style: the view finds the nearest `LabShopFlow` stack
// itself and pushes the cart.
package struct WrapperProductView: View {
    @FlowNavigation(LabShopFlow.self) private var shop

    package var body: some View {
        LabProductContent(
            note: NavigationStyle.wrappers.pusher,
            detail: NavigationStyle.wrappers.explanation,
            isLoadingReviews: false,
            onReviews: nil,
            onAddToCart: { shop.push(LabCartRoute()) }
        )
    }
}

#Preview("Outputs") {
    OutputsProductView(onBuy: { })
        .waypointPreview(flow: LabShopFlow.self)
}

#Preview("Wrappers") {
    WrapperProductView()
        .waypointPreview(flow: LabShopFlow.self)
}
