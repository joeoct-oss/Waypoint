//
//  StackTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The shop's stack runs on Waypoint's SwiftUI renderer. These check that pushes and
// pops draw for real, that what the user does by hand comes back to the router, that a change
// landing while a push still animates is not lost, which needs the transition hold on iOS 17, that
// a double tap pushes once, that a Waypoint link pushes through the router, that Shop's banner
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
    // The lamp's trail on Shop, in either form: `main › shop › orbit lamp` on the bar, or
    // `Route trail: main, shop, orbit lamp` on the strip.
    private static let lampTrail = NSPredicate(
        format: "label CONTAINS 'main' AND label CONTAINS 'shop' AND label CONTAINS 'orbit lamp'"
    )
    private static let lampID = 1
    private static let mugID = 2
    private static let throwID = 3
    private static let launchPath = [
        1,
        2,
        3,
    ]

    // How long a mid-transition test waits for its final screen, counted from the launch, so it
    // covers the app starting, the launch push and the held change on a busy Mac. A
    // lost change never shows the final screen, so a longer wait can't turn a lost change into a
    // pass.
    private static let launchSettleTimeout: TimeInterval = 20

    // A product pushes on Shop and hides the tab bar, and its route trail comes from the stack
    // router: main, shop, then the product, on the bar's subtitle from iOS 26 and on the strip
    // below the bar before that. Back shows the tab bar again. The "Nebula nights"
    // banner pushes its collection on the same stack, and a product in it pushes above the
    // collection, so Back walks the collection and then the shop.
    func testPushAndBack() {
        let app = ExampleApp.launch(signedIn: true)
        app.buttons[Identifiers.product(id: Self.lampID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.waitForTabBar(shown: false), "a pushed screen showed the tab bar")
        let trail = app.descendants(matching: .any).matching(Self.lampTrail).firstMatch
        XCTAssertTrue(trail.waitForExistence(timeout: UITestSteps.timeout), "the trail doesn't follow the router")
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.waitForTabBar(shown: true), "the shop hid the tab bar")

        app.buttons[Identifiers.collection(id: Self.collectionID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.collectionTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.product(id: Self.throwID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.throwTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.collectionTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    // A fast double tap on a row pushes the product once: one Back returns to the
    // shop. Without the duplicate push rule, the second tap pushes the lamp again and Back shows
    // the lamp.
    func testDoubleTapPushesOnce() {
        let app = ExampleApp.launch(signedIn: true)
        let lampRow = app.buttons[Identifiers.product(id: Self.lampID)]
        XCTAssertTrue(lampRow.waitForExistence(timeout: UITestSteps.timeout))

        lampRow.doubleTap()
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

    // The lamp's page links to the mug with a `WaypointLink`. The tap pushes
    // through the
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

        XCTAssertTrue(app.navigationBars[Self.mugTitle].waitForExistence(timeout: Self.launchSettleTimeout))
        XCTAssertTrue(app.staysOn(Self.mugTitle, never: Self.throwTitle), "the pop came undone")
    }

    func testPopToRootMidTransition() {
        let app = ExampleApp.launch(
            signedIn: true,
            shopPath: Self.launchPath,
            shopFollowUp: .popToRoot
        )

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: Self.launchSettleTimeout))
        XCTAssertTrue(app.staysOn(Self.shopTitle, never: Self.throwTitle), "the pop to root came undone")
    }

    func testLinkMidTransition() {
        let app = ExampleApp.launch(
            signedIn: true,
            shopPath: Self.launchPath,
            shopFollowUp: .link
        )

        XCTAssertTrue(app.navigationBars[Self.printTitle].waitForExistence(timeout: Self.launchSettleTimeout))
        XCTAssertTrue(app.staysOn(Self.printTitle, never: Self.throwTitle), "the new path came undone")
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }
}

private extension XCUIApplication {
    // Whether the screen titled `title` is still on top, and `other` still gone, once the stack's
    // transition hold has passed, so a held change that lands and is then undone fails.
    func staysOn(_ title: String, never other: String) -> Bool {
        RunLoop.current.run(until: Date().addingTimeInterval(UITestSteps.settleTime))
        return navigationBars[title].exists && !navigationBars[other].exists
    }
}
