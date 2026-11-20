//
//  SystemLinkTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// A system `NavigationLink(value:)` inside a Waypoint stack is refused and reported (#147). The app
// draws the lamp page's related link as a system link, and its products stacks log navigation
// issues to a banner. `scripts/test-mac.sh full` runs this class a second time in the release
// configuration, where the banner's value says "release", to prove the report doesn't depend on a
// debug build.
@MainActor
final class SystemLinkTests: XCTestCase {
    private static let lampTitle = "Orbit Lamp"
    private static let mugTitle = "Comet Mug"
    private static let lampID = 1

    // How long the screen gets to settle after the stack draws the router's path again.
    private static let settleTimeout: TimeInterval = 3

    func testSystemLinkIsReportedAndRouterPathKept() {
        let app = ExampleApp.launch(
            signedIn: true,
            systemLinks: true
        )
        app.buttons[Identifiers.product(id: Self.lampID)].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))

        let relatedLink = app.buttons[Identifiers.relatedProduct]
        XCTAssertTrue(app.reveal(relatedLink))
        relatedLink.tap()

        let banner = app.descendants(matching: .any)[Identifiers.navigationIssue]
        XCTAssertTrue(banner.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(banner.label.contains("WaypointLink"), banner.label)
        XCTAssertEqual(banner.value as? String, BuildConfiguration.name)
        XCTAssertTrue(waitUntilGone(app.navigationBars[Self.mugTitle]))
        XCTAssertTrue(app.navigationBars[Self.lampTitle].exists)
    }

    // SwiftUI may start showing the mug before the stack draws the router's path again, so this
    // waits for the mug to leave instead of checking once.
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: Self.settleTimeout) == .completed
    }
}
