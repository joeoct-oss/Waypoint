//
//  StackTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The shop's stack runs on Waypoint's SwiftUI renderer (#11). These check that pushes and pops draw
// for real, that what the user does by hand comes back to the router, and that a change landing
// while a push still animates is not lost, which needs the transition hold on iOS 17.
@MainActor
final class StackTests: XCTestCase {
    private static let shopTitle = "Shop"
    private static let lampTitle = "Orbit Lamp"
    private static let mugTitle = "Comet Mug"
    private static let throwTitle = "Nebula Throw"
    private static let clockTitle = "Lunar Clock"
    private static let lampID = 1
    private static let mugID = 2
    private static let launchPath = [
        1,
        2,
        3,
    ]

    // How long the screen gets to settle after a held change, which waits for the push to end.
    private static let settleTimeout: TimeInterval = 3

    func testPushAndBack() {
        let app = ExampleApp.launch(signedIn: true)

        app.buttons[Identifiers.product(id: Self.lampID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    // After a swipe back, the router's path is the shop again: the next product is pushed onto the
    // shop, so one Back returns to it. Had the swipe not reached the router, Back would show the
    // lamp.
    func testSwipeBackReachesRouter() {
        let app = ExampleApp.launch(signedIn: true)
        app.buttons[Identifiers.product(id: Self.lampID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))

        app.swipeBack()
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.product(id: Self.mugID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.mugTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testMultiStepPushShowsLastThenWalksBack() {
        let app = ExampleApp.launch(
            signedIn: true,
            shopPath: Self.launchPath
        )

        XCTAssertTrue(app.navigationBars[Self.throwTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.mugTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testPopMidTransition() {
        let app = ExampleApp.launch(
            signedIn: true,
            shopPath: Self.launchPath,
            shopFollowUp: .pop
        )

        XCTAssertTrue(app.navigationBars[Self.mugTitle].waitForExistence(timeout: Self.settleTimeout))
        XCTAssertFalse(app.navigationBars[Self.throwTitle].exists)
    }

    func testPopToRootMidTransition() {
        let app = ExampleApp.launch(
            signedIn: true,
            shopPath: Self.launchPath,
            shopFollowUp: .popToRoot
        )

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: Self.settleTimeout))
        XCTAssertFalse(app.navigationBars[Self.throwTitle].exists)
    }

    func testLinkMidTransition() {
        let app = ExampleApp.launch(
            signedIn: true,
            shopPath: Self.launchPath,
            shopFollowUp: .link
        )

        XCTAssertTrue(app.navigationBars[Self.clockTitle].waitForExistence(timeout: Self.settleTimeout))
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }
}
