//
//  ViewModelStyleUITests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The Lab's Views and view models stories (planning #363), one test for each on the design canvas:
// every navigation style pushes the same cart, a view model's late push after its flow closed is
// ignored while one made in time pushes, and a wrapper with no stack above it fails with
// `noRouterInScope`.
@MainActor
final class ViewModelStyleUITests: XCTestCase {
    private static let styleTitles = [
        "Outputs",
        "Navigator",
        "Wrappers",
    ]
    private static let ignored = "ignored"
    private static let missingRouter = "noRouterInScope"
    // Reviews take 2.5 seconds to arrive, so the wait for them is longer than the usual one.
    private static let reviewsTimeout: TimeInterval = 8
    private static let lateReviewsSeconds = 8
    private static let lateOutcomeTimeout: TimeInterval = 16
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

    // The reviews take `lateReviewsSeconds` here, so the demo is closed before they arrive even on
    // a slow run; the test waits for the cover to go before it waits for the outcome.
    func testLatePushAfterBackIsIgnored() {
        let app = ExampleApp.launch(lab: true, labReviewsSeconds: Self.lateReviewsSeconds)
        open(.lateResult, in: app)

        app.buttons[Identifiers.labOpenLateDemo].tapWhenReady()
        loadReviews(in: app)
        let close = app.buttons[Identifiers.labDemoClose]
        close.tapWhenReady()
        XCTAssertTrue(close.waitForNonExistence(timeout: Self.reviewsTimeout), "the demo stayed open")

        let outcome = app.staticTexts[Identifiers.labLateOutcome]
        XCTAssertTrue(outcome.waitForExistence(timeout: Self.lateOutcomeTimeout))
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

    // Taps Reviews until the button turns off while the reviews load. The product slides up as a
    // cover, and a tap made while it still moves can miss the button, which would leave no reviews
    // to wait for. Polls by hand, because a predicate expectation checks only about once a second.
    private func loadReviews(in app: XCUIApplication) {
        let reviews = app.buttons[Identifiers.labDemoReviews]
        for _ in 0..<Self.reviewsTapAttempts {
            reviews.tapWhenReady()
            if waitUntilLoading(reviews) {
                return
            }
        }
        XCTFail("Reviews never started loading")
    }

    // Whether the Reviews button turned off within a second. A button that is gone also counts,
    // since the reviews were pushed over it.
    private func waitUntilLoading(_ reviews: XCUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(UITestSteps.settleTime)
        while Date() < deadline {
            if !reviews.exists || !reviews.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(UITestSteps.pollInterval))
        }
        return !reviews.exists || !reviews.isEnabled
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
