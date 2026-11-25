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

    // Settings tries each call in turn. Closing the tab's stack, which no fallback covers, reaches
    // `onNavigationFailure`: the banner shows it, the screen stays, and Settings counts it. Opening
    // sign in while it is up replaces the sheet, so one Cancel leaves nothing presented. Open
    // Orders twice shows the duplicate push rule and its toggle. Going back to a screen that isn't
    // in the stack pops to the root. The event log shows both recoveries.
    func testSettingsTriesWhatTheRulesCover() {
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

        let presentTwice = app.buttons[Identifiers.tryPresentTwice]
        XCTAssertTrue(app.reveal(presentTwice))
        presentTwice.tap()
        let signIn = app.buttons[Identifiers.signInButton]
        XCTAssertTrue(signIn.waitForExistence(timeout: UITestSteps.timeout), "sign in didn't open")
        app.buttons[Identifiers.authCancel].tapWhenReady()
        XCTAssertTrue(signIn.waitForNonExistence(timeout: UITestSteps.timeout), "a second sign in stayed")

        assertPushTwiceRule(in: app)

        let missingPop = app.buttons[Identifiers.tryMissingPop]
        XCTAssertTrue(app.reveal(missingPop))
        missingPop.tap()
        XCTAssertTrue(app.navigationBars[Self.accountTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(app.navigationBars[Self.settingsTitle].exists, "the fallback left Settings open")
        // The banner may still show the unrecovered call, so this waits for the popTo's own issue.
        let popToIssue = expectation(for: Self.missingRoute, evaluatedWith: banner)
        let popToWaits = [popToIssue]
        let shown = XCTWaiter.wait(for: popToWaits, timeout: UITestSteps.timeout)
        XCTAssertEqual(shown, .completed, "the banner didn't show the issue: \(banner.label)")

        // The log lists the newest call first, so the popTo comes before the replaced sheet: a row
        // scrolled above the screen leaves the list, and `reveal` can't scroll back to it.
        app.openLabTool(.eventLog)
        let popped = recoveredEntries(in: app).matching(Self.missingRoute).firstMatch
        XCTAssertTrue(app.reveal(popped), "the event log doesn't show the recovered popTo")
        let replaced = recoveredEntries(in: app).matching(Self.alreadyPresenting).firstMatch
        XCTAssertTrue(app.reveal(replaced), "the event log doesn't show the replaced sheet")
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
