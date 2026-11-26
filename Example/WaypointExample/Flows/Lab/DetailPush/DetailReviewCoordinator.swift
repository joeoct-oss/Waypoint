//
//  DetailReviewCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleStore
import SwiftUI
import Waypoint

// Write a review, the child flow the Lab's Detail push flow pushes on its own stack from a product.
// Its screens follow the product on the same stack: the rating first, then the
// note the rating pushes on the review flow's own router. The note's Post review finishes the
// flow with the stars from the view itself, with `@FinishFlow(DetailReviewCoordinator.self)`,
// which pops back to the product. Back past the rating ends it, which the Detail push flow gets as
// `.cancelled`.
//
// Conformances:
// - `FlowCoordinator`, so the Detail push flow pushes it with `push(_:onFinish:)` and gets the
//   stars.
package final class DetailReviewCoordinator: FlowCoordinator {
    // The stars the review gives.
    package typealias Output = Int

    private let product: Product
    private let factory: LabFactory

    // The journey's name for the flow's first screen.
    package var rootName: String {
        "Write a review"
    }

    package var root: some View {
        factory.makeDetailReviewRating(onRate: { self.showNote(rating: $0) })
            .screenChrome(
                title: rootName,
                kind: .swiftUI,
                router: router,
                route: nil
            )
    }

    package var destinations: some Destinations {
        Destination(DetailReviewNoteRoute.self) { self.makeNoteScreen($0) }
    }

    // `LabFactory` makes it, and builds its screens.
    package init(
        product: Product,
        factory: LabFactory
    ) {
        self.product = product
        self.factory = factory
    }

    package func makeNoteScreen(_ route: DetailReviewNoteRoute) -> some View {
        factory.makeDetailReviewNote(rating: route.rating)
            .screenChrome(
                title: "Your review",
                kind: .swiftUI,
                router: router,
                route: AnyRoute(route)
            )
    }

    package func showNote(rating: Int) {
        router.push(DetailReviewNoteRoute(rating: rating))
    }
}
