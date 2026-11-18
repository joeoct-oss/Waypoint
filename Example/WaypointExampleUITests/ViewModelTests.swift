//
//  ViewModelTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The Lab's Views and view models stories (#179), one test for each on the design canvas: every
// navigation style pushes the same cart, a view model's late push after its flow closed is
// ignored while one made in time pushes, and a wrapper with no stack above it fails with
// `noRouterInScope`.
@MainActor
final class ViewModelTests: XCTestCase {
    private static let styleTitles = [
        "Outputs",
        "Navigator",
        "Wrappers",
    ]
    private static let ignored = "ignored"
    private static let missingRouter = "noRouterInScope"
    // Reviews take 2.5 seconds to arrive, so the wait for them is longer than the usual one.
    private static let reviewsTimeout: TimeInterval = 8
    // What the Reviews button says while the reviews load.
    private static let loadingLabel = "Loading…"
    private static let reviewsTapAttempts = 3

    func testEachStyleBuysTheSameWay() {
        let app = ExampleApp.launch(lab: true)
        open(.style, in: app)

        for title in Self.styleTitles {
            app.buttons[title].tapWhenReady()
            app.buttons[Identifiers.labTryStyle].tapWhenReady()
            app.buttons[Identifiers.labDemoAddToCart].tapWhenReady()
            let cart = app.descendants(matching: .any)[Identifiers.labDemoCart]
            XCTAssertTrue(cart.waitForExistence(timeout: UITestSteps.timeout), "\(title) didn't push the cart")
            app.goBack()
            app.buttons[Identifiers.labDemoClose].tapWhenReady()
        }
    }

    func testLatePushAfterBackIsIgnored() {
        let app = ExampleApp.launch(lab: true)
        open(.lateResult, in: app)

        app.buttons[Identifiers.labOpenLateDemo].tapWhenReady()
        loadReviews(in: app)
        app.buttons[Identifiers.labDemoClose].tapWhenReady()

        let outcome = app.staticTexts[Identifiers.labLateOutcome]
        XCTAssertTrue(outcome.waitForExistence(timeout: Self.reviewsTimeout))
        XCTAssertEqual(outcome.label, Self.ignored)
        XCTAssertFalse(app.descendants(matching: .any)[Identifiers.labDemoReviewsScreen].exists)
    }

    func testReviewsInTimePushThroughNavigator() {
        let app = ExampleApp.launch(lab: true)
        open(.lateResult, in: app)

        app.buttons[Identifiers.labOpenLateDemo].tapWhenReady()
        loadReviews(in: app)

        let reviews = app.descendants(matching: .any)[Identifiers.labDemoReviewsScreen]
        XCTAssertTrue(reviews.waitForExistence(timeout: Self.reviewsTimeout))
    }

    func testWrapperWithoutRouterReportsIssue() {
        let app = ExampleApp.launch(lab: true)
        open(.noRouter, in: app)

        app.buttons[Identifiers.labOpenReviews].tapWhenReady()

        let issue = app.descendants(matching: .any)[Identifiers.labMissingRouter]
        XCTAssertTrue(issue.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(issue.label.contains(Self.missingRouter), "the issue doesn't name noRouterInScope")
    }

    // Taps Reviews until the button says it is loading. The product slides up as a cover, and a tap
    // made while it still moves can miss the button, which would leave no reviews to wait for.
    private func loadReviews(in app: XCUIApplication) {
        let reviews = app.buttons[Identifiers.labDemoReviews]
        let loading = NSPredicate(format: "label == %@", Self.loadingLabel)
        for _ in 0..<Self.reviewsTapAttempts {
            reviews.tapWhenReady()
            let started = XCTNSPredicateExpectation(predicate: loading, object: reviews)
            if XCTWaiter.wait(for: [started], timeout: UITestSteps.settleTime) == .completed {
                return
            }
        }
        XCTFail("Reviews never started loading")
    }

    private func open(
        _ story: ViewModelStory,
        in app: XCUIApplication
    ) {
        let row = app.buttons[Identifiers.labStory(story)]
        XCTAssertTrue(app.reveal(row), "missing \(Identifiers.labStory(story))")
        row.tap()
    }
}
