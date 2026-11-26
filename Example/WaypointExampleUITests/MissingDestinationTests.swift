//
//  MissingDestinationTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// A route the router knows, pushed onto a stack where no screen draws it, shows Waypoint's
// missing-destination screen and reports `missingDestination`. With the
// `missingDestination` launch argument, the lamp page's related link pushes the lamp's reviews,
// which the registry lists but no products screen draws. Debug builds show the debug screen that
// names the route and the fix. `scripts/test-mac.sh full` runs this class a second time in the
// release configuration, where the screen is blank, the issue is still reported, and Back still
// works.
@MainActor
final class MissingDestinationTests: XCTestCase {
    private static let lampTitle = "Orbit Lamp"
    private static let lampID = 1
    private static let routeName = "ProductReviewsRoute"

    func testRouteWithNoDestinationInItsStackIsShownAndReported() {
        let app = ExampleApp.launch(
            signedIn: true,
            missingDestination: true
        )
        app.buttons[Identifiers.product(id: Self.lampID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))

        let relatedLink = app.buttons[Identifiers.relatedProduct]
        XCTAssertTrue(app.reveal(relatedLink))
        relatedLink.tap()

        // The stack checks for a missing destination when the push ends, about 0.6 s after the tap.
        let banner = app.descendants(matching: .any)[Identifiers.navigationIssue]
        XCTAssertTrue(banner.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(banner.label.contains(Self.routeName), banner.label)
        XCTAssertEqual(banner.value as? String, BuildConfiguration.name)
        checkScreen(in: app)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    // Debug builds show the debug screen, which names the route type. Release builds show none.
    private func checkScreen(in app: XCUIApplication) {
        let title = app.staticTexts[Identifiers.missingDestinationTitle]
        #if DEBUG
            XCTAssertTrue(title.waitForExistence(timeout: UITestSteps.timeout))
            XCTAssertTrue(title.label.contains(Self.routeName), title.label)
        #else
            XCTAssertFalse(title.exists)
        #endif
    }
}
