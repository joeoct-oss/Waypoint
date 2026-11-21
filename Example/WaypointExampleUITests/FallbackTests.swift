//
//  FallbackTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// What the app does when a navigation call can't happen (#280). The main tab router sets two
// fallbacks every flow inherits: a `popTo` of a screen that isn't in the stack pops to the root,
// and a present while a flow is up replaces it. Each recovery shows in the issue banner over the
// tabs and as a recovered entry in the Lab's event log. Settings' toggle changes the duplicate
// push rule, so a fast double tap pushes twice, and counts a call no fallback covers.
@MainActor
final class FallbackTests: XCTestCase {
    private static let accountTitle = "Account"
    private static let settingsTitle = "Settings"
    private static let shopTitle = "Shop"
    private static let lampTitle = "Orbit Lamp"
    private static let lampID = 1
    private static let recovered = "recovered"
    private static let switchOn = "1"
    private static let oneFailure = "1"
    // How the log words the two recoveries.
    private static let missingRoute = NSPredicate(format: "label CONTAINS \"isn't in the stack\"")
    private static let alreadyPresenting = NSPredicate(format: "label CONTAINS 'already presents'")

    func testFailedPopToFallsBackToRoot() {
        let app = openSettings()
        app.buttons[Identifiers.tryMissingPop].tapWhenReady()

        XCTAssertTrue(app.navigationBars[Self.accountTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(app.navigationBars[Self.settingsTitle].exists, "the fallback left Settings open")
        let banner = app.descendants(matching: .any)[Identifiers.navigationIssue]
        XCTAssertTrue(banner.waitForExistence(timeout: UITestSteps.timeout), "the banner didn't show the issue")

        app.openLabTool(.eventLog)
        let entry = recoveredEntries(in: app).matching(Self.missingRoute).firstMatch
        XCTAssertTrue(app.reveal(entry), "the event log doesn't show the recovered popTo")
    }

    func testPresentOverSheetReplacesIt() {
        let app = openSettings()
        app.buttons[Identifiers.tryPresentTwice].tapWhenReady()

        let signIn = app.buttons[Identifiers.signInButton]
        XCTAssertTrue(signIn.waitForExistence(timeout: UITestSteps.timeout), "sign in didn't open")
        app.buttons[Identifiers.authCancel].tapWhenReady()
        // One sheet replaced the other, so one Cancel leaves nothing presented.
        XCTAssertTrue(signIn.waitForNonExistence(timeout: UITestSteps.timeout), "a second sign in stayed")

        app.goBack()
        app.openLabTool(.eventLog)
        let entry = recoveredEntries(in: app).matching(Self.alreadyPresenting).firstMatch
        XCTAssertTrue(app.reveal(entry), "the event log doesn't show the replaced sheet")
    }

    // A call no fallback covers reaches `onNavigationFailure`, which Settings counts.
    func testUnrecoveredCallIsCounted() {
        let app = openSettings()
        let count = app.descendants(matching: .any)[Identifiers.failureCount]
        XCTAssertTrue(app.reveal(count))
        XCTAssertFalse(count.label.contains(Self.oneFailure), count.label)

        app.buttons[Identifiers.tryUnrecovered].tapWhenReady()
        let banner = app.descendants(matching: .any)[Identifiers.navigationIssue]
        XCTAssertTrue(banner.waitForExistence(timeout: UITestSteps.timeout), "the banner didn't show the failure")
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].exists, "a failed call moved the screen")
        let counted = NSPredicate(format: "label CONTAINS %@", Self.oneFailure)
        let wait = expectation(for: counted, evaluatedWith: count)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: UITestSteps.timeout), .completed, count.label)
    }

    func testDuplicatePushRuleFromSettings() {
        let app = openSettings(signedIn: true)
        let toggle = app.switches[Identifiers.duplicatePushRule]
        XCTAssertTrue(app.reveal(toggle))
        // The row's own switch, since a tap in the middle of a SwiftUI toggle's row may not
        // flip it.
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, Self.switchOn, "the toggle stayed off")
        app.goBack()

        app.openTab(Self.shopTitle)
        let lampRow = app.buttons[Identifiers.product(id: Self.lampID)]
        XCTAssertTrue(lampRow.waitForExistence(timeout: UITestSteps.timeout))
        lampRow.doubleTap()
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()

        // The second tap pushed the lamp again, so one Back shows the lamp, not the shop.
        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    private func openSettings(signedIn: Bool = false) -> XCUIApplication {
        let app = ExampleApp.launch(signedIn: signedIn)
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.settingsButton].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: UITestSteps.timeout))
        return app
    }

    private func recoveredEntries(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: Identifiers.eventLogEntry(Self.recovered))
    }
}
