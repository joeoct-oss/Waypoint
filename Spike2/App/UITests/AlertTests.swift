import XCTest

/// Spike F: alerts in the state, against sheet dismissals, in both renderers.
final class AlertTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func alertSummary(_ app: XCUIApplication) -> String {
        let alerts = app.alerts.allElementsBoundByIndex
        return alerts.isEmpty ? "no alert" : "\(alerts.count) alert(s) '\(alerts[0].label)'"
    }

    private func sheetShown(_ app: XCUIApplication) -> Bool {
        app.navigationBars["S"].exists || app.staticTexts["S"].exists
    }

    private func answer(_ app: XCUIApplication) {
        for title in ["OK", "Delete"] where app.alerts.buttons[title].firstMatch.exists {
            app.alerts.buttons[title].firstMatch.tap()
            return
        }
    }

    private func launchF(_ renderer: String, _ mode: String) -> XCUIApplication {
        launch(["-scenario", "f", "-renderer", renderer] + (mode == "sequenced" ? ["-sequenced"] : []))
    }

    private func presentSheet(_ app: XCUIApplication, _ renderer: String) {
        tap(app, renderer == "uiKit" ? "presentUIKit" : "presentSwiftUI")
        sleep(2)
    }

    private func each(_ body: (String, String) -> Void) {
        for renderer in ["uiKit", "swiftUI"] {
            for mode in ["naive", "sequenced"] {
                body(renderer, mode)
            }
        }
    }

    /// The sheet is dismissed and an alert asked for in the same turn, or 150 ms later.
    func testAlertWhileSheetCloses() {
        for action in ["dismissAndAlert", "dismissThenAlertSoon"] {
            each { renderer, mode in
                let app = launchF(renderer, mode)
                let tag = "F-\(action)-\(renderer)-\(mode)"
                presentSheet(app, renderer)
                tap(app, action)
                usleep(400_000)
                shot("\(tag)-1-mid")
                sleep(2)
                let seen = alertSummary(app)
                shot("\(tag)-2-after")
                answer(app)
                sleep(1)
                finding("\(tag): after 2.4 s \(seen), sheet=\(sheetShown(app)) state=\(state(app)) notes=\(notes(app))")
            }
        }
    }

    /// The root flow asks for an alert while its sheet stays up, then the sheet is dismissed.
    func testAlertUnderSheet() {
        each { renderer, mode in
            let app = launchF(renderer, mode)
            let tag = "F-alertUnderSheet-\(renderer)-\(mode)"
            presentSheet(app, renderer)
            tap(app, "alertUnderSheet")
            sleep(2)
            let during = alertSummary(app)
            shot("\(tag)-1-sheet-up")
            if app.alerts.count > 0 { answer(app); sleep(1) }
            if app.buttons["dismissSheet"].exists { app.buttons["dismissSheet"].firstMatch.tap() }
            sleep(2)
            let after = alertSummary(app)
            shot("\(tag)-2-after-dismiss")
            answer(app)
            sleep(1)
            finding("\(tag): with sheet up \(during); after dismiss \(after); state=\(state(app)) notes=\(notes(app))")
        }
    }

    /// An alert is up when a link closes it, sets a path and presents a sheet in one change.
    func testLinkOverAlert() {
        each { renderer, mode in
            let app = launchF(renderer, mode)
            let tag = "F-alertThenLink-\(renderer)-\(mode)"
            tap(app, "alertThenLink")
            sleep(4)
            shot("\(tag)-1-after-link")
            finding("\(tag): \(alertSummary(app)) sheet=\(sheetShown(app)) state=\(state(app)) notes=\(notes(app))")
        }
    }
}
