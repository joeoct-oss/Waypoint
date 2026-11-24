//
//  FallbackTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// What the app does when a navigation call can't happen (planning #415). The main tab router sets
// two fallbacks every flow inherits: a `popTo` of a screen that isn't in the stack pops to the
// root, and a present while a flow is up replaces it. Each recovery shows in the issue banner over
// the tabs and as a recovered entry in the Lab's event log. Settings' toggle changes the duplicate
// push rule, which Open Orders twice tries, and Settings counts a call no fallback covers.
@MainActor
final class FallbackTests: XCTestCase {
    private static let accountTitle = "Account"
    private static let settingsTitle = "Settings"
    private static let ordersTitle = "Orders"
    // How long a Back takes to settle, so a screen that isn't coming back has had its chance.
    private static let settleTime: TimeInterval = 1
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
        let waits = [wait]
        XCTAssertEqual(XCTWaiter.wait(for: waits, timeout: UITestSteps.timeout), .completed, count.label)
    }

    // A real double tap can't show the rule: iOS drops the second tap while the push animates. Open
    // Orders twice pushes again while the first push still animates instead.
    func testDuplicatePushRuleFromSettings() {
        let app = openSettings(signedIn: true)
        let pushTwice = app.buttons[Identifiers.tryPushTwice]

        // By default the second push is skipped, so one Back returns to Settings.
        XCTAssertTrue(app.reveal(pushTwice))
        pushTwice.tap()
        XCTAssertTrue(app.navigationBars[Self.ordersTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: UITestSteps.timeout))

        let toggle = app.switches[Identifiers.duplicatePushRule]
        XCTAssertTrue(app.reveal(toggle))
        XCTAssertTrue(toggle.setSwitch(to: Self.switchOn), "the toggle stayed off")

        // With `.allow` both pushes go through, so one Back still shows Orders.
        XCTAssertTrue(app.reveal(pushTwice))
        pushTwice.tap()
        XCTAssertTrue(app.navigationBars[Self.ordersTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        let settings = app.navigationBars[Self.settingsTitle]
        XCTAssertFalse(settings.waitForExistence(timeout: Self.settleTime), "only one Orders was pushed")
        XCTAssertTrue(app.navigationBars[Self.ordersTitle].exists)
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: UITestSteps.timeout))
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
