//
//  DetailReviewCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Write a review, the child flow the Lab's Detail push flow pushes on its own stack from a product
// (#59). Its screens follow the product on the same stack: the rating first, then the note the
// rating pushes on the review flow's own router. Post review finishes the flow with the stars,
// which pops back to the product. Back past the rating ends it, which the Detail push flow gets as
// `.cancelled`.
//
// Conformances:
// - `FlowCoordinator`, so the Detail push flow pushes it with `push(_:onFinish:)` and gets the
//   stars.
final class DetailReviewCoordinator: FlowCoordinator {
    // The stars the review gives.
    typealias Output = Int

    private let product: Product

    // The journey's name for the flow's first screen.
    var rootName: String {
        "Write a review"
    }

    var root: some View {
        DetailReviewRatingView(onRate: { self.showNote(rating: $0) })
            .screenChrome(
                title: rootName,
                kind: .swiftUI,
                router: router,
                route: nil
            )
    }

    var destinations: some Destinations {
        Destination(DetailReviewNoteRoute.self) { self.makeNoteScreen($0) }
    }

    init(product: Product) {
        self.product = product
    }

    func makeNoteScreen(_ route: DetailReviewNoteRoute) -> some View {
        DetailReviewNoteView(
            rating: route.rating,
            onPost: { self.post(rating: route.rating) }
        )
        .screenChrome(
            title: "Your review",
            kind: .swiftUI,
            router: router,
            route: AnyRoute(route)
        )
    }

    func showNote(rating: Int) {
        router.push(DetailReviewNoteRoute(rating: rating))
    }

    func post(rating: Int) {
        finish(with: rating)
    }
}
