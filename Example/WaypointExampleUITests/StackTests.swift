//
//  StackTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The shop's stack runs on Waypoint's SwiftUI renderer (#11). These check that pushes and pops draw
// for real, that what the user does by hand comes back to the router, that a change landing
// while a push still animates is not lost, which needs the transition hold on iOS 17, that a
// double tap pushes once, that a Waypoint link pushes through the router, that Shop's banner
// pushes its collection, and that pushed screens hide the tab bar.
@MainActor
final class StackTests: XCTestCase {
    private static let shopTitle = "Shop"
    private static let lampTitle = "Orbit Lamp"
    private static let mugTitle = "Comet Mug"
    private static let throwTitle = "Nebula Throw"
    private static let printTitle = "Star Chart Print"
    private static let collectionTitle = "Nebula nights"
    private static let collectionID = "nebula-nights"
    private static let lampID = 1
    private static let mugID = 2
    private static let throwID = 3
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
        XCTAssertTrue(app.waitForTabBar(shown: false), "a pushed screen showed the tab bar")
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.waitForTabBar(shown: true), "the shop hid the tab bar")
    }

    // The "Nebula nights" banner pushes its collection on the Shop stack, and a product in it
    // pushes above the collection, so Back walks the collection and then the shop.
    func testBannerOpensCollection() {
        let app = ExampleApp.launch(signedIn: true)

        app.buttons[Identifiers.collection(id: Self.collectionID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.collectionTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.product(id: Self.throwID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.throwTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.collectionTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    // A fast double tap on a row pushes the product once (#142): one Back returns to the shop.
    // Without the duplicate push rule, the second tap pushes the lamp again and Back shows the
    // lamp.
    func testDoubleTapPushesOnce() {
        let app = ExampleApp.launch(signedIn: true)
        let lampRow = app.buttons[Identifiers.product(id: Self.lampID)]
        XCTAssertTrue(lampRow.waitForExistence(timeout: UITestSteps.timeout))

        lampRow.doubleTap()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: Self.settleTimeout))
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

    // The lamp's page links to the mug with a `WaypointLink` (#147). The tap pushes through the
    // router: the mug shows, nothing is reported, and Back walks the router's path, the lamp and
    // then the shop.
    func testWaypointLinkPushesThroughRouter() {
        let app = ExampleApp.launch(signedIn: true)
        app.buttons[Identifiers.product(id: Self.lampID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))

        let relatedLink = app.buttons[Identifiers.relatedProduct]
        XCTAssertTrue(app.reveal(relatedLink))
        relatedLink.tap()

        XCTAssertTrue(app.navigationBars[Self.mugTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(app.descendants(matching: .any)[Identifiers.navigationIssue].exists)
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
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

        XCTAssertTrue(app.navigationBars[Self.printTitle].waitForExistence(timeout: Self.settleTimeout))
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }
}
