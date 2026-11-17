import XCTest

/// Spike E: a link presents a Waypoint sheet while a screen Waypoint didn't present is up.
final class ForeignTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func waypointSheetShown(_ app: XCUIApplication) -> Bool {
        app.navigationBars["S"].exists || app.staticTexts["S"].exists
    }

    /// Opens the foreign screen, lets the link land under it, then closes it.
    private func run(_ kind: String, renderer: String, policy: String, close: (XCUIApplication) -> Void) {
        let app = launch(["-scenario", "e", "-renderer", renderer, "-policy", policy])
        let tag = "E-\(kind)-\(renderer)-\(policy)"
        tap(app, "linkSoon")
        tap(app, kind)
        sleep(3) // the link lands 1.5 s after linkSoon, while the foreign screen is up
        shot("\(tag)-1-link-under-foreign")
        let during = waypointSheetShown(app)
        close(app)
        sleep(3)
        shot("\(tag)-2-after-close")
        finding("\(tag): sheet during foreign=\(during) after close=\(waypointSheetShown(app)) state=\(state(app)) notes=\(notes(app))")
    }

    private func closeSDK(_ app: XCUIApplication) {
        if app.buttons["sdk.close"].exists { app.buttons["sdk.close"].tap() }
    }

    private func closeAlert(_ app: XCUIApplication) {
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
    }

    private func closeAppSheet(_ app: XCUIApplication) {
        if app.buttons["appsheet.close"].exists { app.buttons["appsheet.close"].tap() }
    }

    private func closeShare(_ app: XCUIApplication) {
        let close = app.buttons["Close"]
        if close.exists { close.tap() } else { app.swipeDown(velocity: .fast) }
    }

    private func closeSafari(_ app: XCUIApplication) {
        // The Safari view's close button is out of process; tap where it is drawn (top left).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.095, dy: 0.1)).tap()
    }

    private func closeSystem(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.element(boundBy: 1)
        if allow.waitForExistence(timeout: 3) { allow.tap() }
    }

    func testSDKSheet() {
        for renderer in ["uiKit", "swiftUI"] {
            for policy in ["naive", "wait", "dismiss"] {
                run("sdkSheet", renderer: renderer, policy: policy, close: closeSDK)
            }
        }
    }

    func testOtherForeignScreensWait() {
        for renderer in ["uiKit", "swiftUI"] {
            run("sdkCover", renderer: renderer, policy: "wait", close: closeSDK)
            run("appAlert", renderer: renderer, policy: "wait", close: closeAlert)
            run("share", renderer: renderer, policy: "wait", close: closeShare)
            run("safari", renderer: renderer, policy: "wait", close: closeSafari)
            run("swiftuiSheet", renderer: renderer, policy: "wait", close: closeAppSheet)
        }
    }

    func testShareAndSafari() {
        for renderer in ["uiKit", "swiftUI"] {
            run("share", renderer: renderer, policy: "wait", close: closeShare)
            run("safari", renderer: renderer, policy: "wait", close: closeSafari)
        }
    }

    func testSafari() {
        for renderer in ["uiKit", "swiftUI"] {
            run("safari", renderer: renderer, policy: "wait", close: closeSafari)
        }
    }

    func testSystemAlert() {
        // The permission alert runs outside the app; resetting lets it show again.
        for renderer in ["uiKit", "swiftUI"] {
            run("systemAlert", renderer: renderer, policy: "wait", close: closeSystem)
        }
    }
}
