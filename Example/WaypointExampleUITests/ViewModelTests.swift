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
        app.buttons[Identifiers.labDemoReviews].tapWhenReady()
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
        app.buttons[Identifiers.labDemoReviews].tapWhenReady()

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

    private func open(
        _ story: ViewModelStory,
        in app: XCUIApplication
    ) {
        let row = app.buttons[Identifiers.labStory(story)]
        XCTAssertTrue(app.reveal(row), "missing \(Identifiers.labStory(story))")
        row.tap()
    }
}
