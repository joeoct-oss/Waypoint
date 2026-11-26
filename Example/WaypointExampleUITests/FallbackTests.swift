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
// the tabs and as a recovered entry in the Lab's event log, and Settings counts a call no fallback
// covers. Settings' toggle changes the duplicate push rule, which Open Orders twice tries.
@MainActor
final class FallbackTests: XCTestCase {
    private static let accountTitle = "Account"
    private static let settingsTitle = "Settings"
    private static let ordersTitle = "Orders"
    // How long a Back takes to settle, so a screen that isn't coming back has had its chance.
    private static let settleTime: TimeInterval = 1
    private static let switchOn = "1"
    private static let recovered = "recovered"
    private static let oneFailure = "1"
    // How the log and the banner word the two recoveries.
    private static let missingRoute = NSPredicate(format: "label CONTAINS \"isn't in the stack\"")
    private static let alreadyPresenting = NSPredicate(format: "label CONTAINS 'already presents'")

    // Each of Settings' tries is its own test, so the four run on different workers instead of one
    // test taking about 100 s (planning #489).

    // Closing the tab's stack, which no fallback covers, reaches `onNavigationFailure`: the banner
    // shows it, the screen stays, and Settings counts it.
    func testUncoveredCallIsReportedAndCounted() {
        let app = openSettings()
        let count = app.descendants(matching: .any)[Identifiers.failureCount]
        XCTAssertTrue(app.reveal(count))
        XCTAssertFalse(count.label.contains(Self.oneFailure), count.label)
        // Revealed before the tap like every other row here: on a loaded Mac the row once sat with
        // only its top 2 pt above the window's bottom edge, XCTest counted it as tappable, and the
        // tap landed on the edge instead of the button (planning #479).
        let unrecovered = app.buttons[Identifiers.tryUnrecovered]
        XCTAssertTrue(app.reveal(unrecovered))
        unrecovered.tap()
        let banner = app.descendants(matching: .any)[Identifiers.navigationIssue]
        XCTAssertTrue(banner.waitForExistence(timeout: UITestSteps.timeout), "the banner didn't show the failure")
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].exists, "a failed call moved the screen")
        let counted = NSPredicate(format: "label CONTAINS %@", Self.oneFailure)
        let wait = expectation(for: counted, evaluatedWith: count)
        let waits = [wait]
        XCTAssertEqual(XCTWaiter.wait(for: waits, timeout: UITestSteps.timeout), .completed, count.label)
    }

    // Opening sign in while it is up replaces the sheet, so one Cancel leaves nothing presented,
    // and the event log shows the recovery.
    func testPresentWhilePresentingReplacesTheSheet() {
        let app = openSettings()
        let presentTwice = app.buttons[Identifiers.tryPresentTwice]
        XCTAssertTrue(app.reveal(presentTwice))
        presentTwice.tap()
        let signIn = app.buttons[Identifiers.signInButton]
        XCTAssertTrue(signIn.waitForExistence(timeout: UITestSteps.timeout), "sign in didn't open")
        app.buttons[Identifiers.authCancel].tapWhenReady()
        XCTAssertTrue(signIn.waitForNonExistence(timeout: UITestSteps.timeout), "a second sign in stayed")

        // The event log opens from Account's root, so this goes back from Settings first.
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.accountTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.openLabTool(.eventLog)
        let replaced = recoveredEntries(in: app).matching(Self.alreadyPresenting).firstMatch
        XCTAssertTrue(app.reveal(replaced), "the event log doesn't show the replaced sheet")
    }

    // Open Orders twice shows the duplicate push rule and its toggle.
    func testPushTwiceFollowsTheDuplicatePushRule() {
        let app = openSettings()
        assertPushTwiceRule(in: app)
    }

    // Going back to a screen that isn't in the stack pops to the root, the banner names the
    // missing screen, and the event log shows the recovery.
    func testPopToMissingScreenPopsToRoot() {
        let app = openSettings()
        let missingPop = app.buttons[Identifiers.tryMissingPop]
        XCTAssertTrue(app.reveal(missingPop))
        missingPop.tap()
        XCTAssertTrue(app.navigationBars[Self.accountTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(app.navigationBars[Self.settingsTitle].exists, "the fallback left Settings open")
        let banner = app.descendants(matching: .any)[Identifiers.navigationIssue]
        let popToIssue = expectation(for: Self.missingRoute, evaluatedWith: banner)
        let popToWaits = [popToIssue]
        let shown = XCTWaiter.wait(for: popToWaits, timeout: UITestSteps.timeout)
        XCTAssertEqual(shown, .completed, "the banner didn't show the issue: \(banner.label)")

        app.openLabTool(.eventLog)
        let popped = recoveredEntries(in: app).matching(Self.missingRoute).firstMatch
        XCTAssertTrue(app.reveal(popped), "the event log doesn't show the recovered popTo")
    }

    // A real double tap can't show the duplicate push rule: iOS drops the second tap while the push
    // animates. Open Orders twice pushes again while the first push still animates instead. By
    // default the second push is skipped, so one Back returns to Settings; with the toggle on,
    // `.allow` lets both through, so one Back still shows Orders.
    private func assertPushTwiceRule(in app: XCUIApplication) {
        let pushTwice = app.buttons[Identifiers.tryPushTwice]
        XCTAssertTrue(app.reveal(pushTwice))
        pushTwice.tap()
        XCTAssertTrue(app.navigationBars[Self.ordersTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: UITestSteps.timeout))

        let toggle = app.switches[Identifiers.duplicatePushRule]
        XCTAssertTrue(app.reveal(toggle))
        XCTAssertTrue(toggle.setSwitch(to: Self.switchOn), "the toggle stayed off")
        XCTAssertTrue(app.reveal(pushTwice))
        pushTwice.tap()
        XCTAssertTrue(app.navigationBars[Self.ordersTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        let settings = app.navigationBars[Self.settingsTitle]
        XCTAssertFalse(settings.waitForExistence(timeout: Self.settleTime), "only one Orders was pushed")
        XCTAssertTrue(app.navigationBars[Self.ordersTitle].exists)
        app.goBack()
        XCTAssertTrue(settings.waitForExistence(timeout: UITestSteps.timeout))
    }

    private func openSettings() -> XCUIApplication {
        let app = ExampleApp.launch(signedIn: true)
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.settingsButton].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: UITestSteps.timeout))
        return app
    }

    private func recoveredEntries(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: Identifiers.eventLogEntry(Self.recovered))
    }
}
