//
//  DetailReviewCoordinatorTests.swift
//  ExampleLabTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleLab
import ExampleStore
import ExampleTestSupport
import Testing
import Waypoint

// The Lab's Write a review flow, pushed on the Detail push stack: its screens
// follow the product on the parent's stack, finishing with the stars pops back to the product, and
// the Detail push flow keeps the stars a posted review gave. Post review finishes from the note
// view with `@FinishFlow`, which the Lab's UI test drives (`LabTests`).
struct DetailReviewCoordinatorTests {
    private static let productID = 1
    private static let rating = 4

    @Test("The note shows on the review's own stack, and finishing with the stars pops back")
    func postingTheReviewFinishesWithTheStarsAndPopsBack() throws {
        let product = try #require(Product.find(id: Self.productID))
        let parent = StackRouter()
        parent.register(DetailProductRoute.self)
        parent.push(DetailProductRoute(productID: product.id))
        let review = TestLab.makeFactory().makeDetailReview(for: product)
        let results = ResultLog<Int>()

        let outcome = parent.push(review) { result in
            results.record(result)
        }
        review.showNote(rating: Self.rating)
        let reviewPath = review.router.state.path
        review.finish(with: Self.rating)

        #expect(outcome == .applied)
        let expectedReviewPath = [AnyRoute(DetailReviewNoteRoute(rating: Self.rating))]
        #expect(reviewPath == expectedReviewPath)
        let expectedResults: [FlowResult<Int>] = [.finished(Self.rating)]
        #expect(results.values == expectedResults)
        let expectedParentPath = [AnyRoute(DetailProductRoute(productID: product.id))]
        #expect(parent.state.path == expectedParentPath)
    }

    @Test("A posted review is shown and a cancelled one is not")
    func postedReviewIsShownAndALeftOneIsNot() throws {
        let product = try #require(Product.find(id: Self.productID))
        let detailPush = TestLab.makeFactory().makeDetailPush(onClose: { })

        detailPush.reviewEnded(.cancelled, for: product)
        let afterCancel = detailPush.postedReviews[product.id]
        detailPush.reviewEnded(.finished(Self.rating), for: product)

        #expect(afterCancel == nil)
        #expect(detailPush.postedReviews[product.id] == Self.rating)
    }

    @Test("Write a review pushes its flow above the product")
    func writeReviewPushesTheFlowAboveTheProduct() throws {
        let product = try #require(Product.find(id: Self.productID))
        let detailPush = TestLab.makeFactory().makeDetailPush(onClose: { })
        detailPush.showProduct(product)

        detailPush.writeReview(for: product)

        #expect(detailPush.router.state.path.count == 2)
        #expect(detailPush.router.children.count == 1)
    }
}
