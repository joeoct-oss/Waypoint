import XCTest

/// Spike D: one app coordinator per window on iPad.
final class WindowTests: XCTestCase {
    private func states(_ app: XCUIApplication) -> [String] {
        app.staticTexts.matching(identifier: "windowState").allElementsBoundByIndex.map(\.label).sorted()
    }

    /// The first prototype kept the coordinator in `@State`: what happens on a second window.
    func testEagerStateSecondWindow() {
        let app = launch(["-scenario", "d", "-eagerState"])
        XCTAssertTrue(app.buttons["newWindow"].waitForExistence(timeout: 5))
        app.buttons["newWindow"].firstMatch.tap()
        sleep(3)
        finding("D eager @State after newWindow: \(states(app))")
        app.buttons.matching(identifier: "push").firstMatch.tap()
        sleep(1)
        finding("D eager @State after push: \(states(app))")
    }

    func testTwoWindows() {
        let app = launch(["-scenario", "d"])
        XCTAssertTrue(app.buttons["newWindow"].waitForExistence(timeout: 5))
        finding("D start: \(states(app))")
        app.buttons["newWindow"].firstMatch.tap()
        sleep(3)
        finding("D after newWindow: windows=\(app.windows.count) states=\(states(app))")
        shot("D-1-two-windows")

        // Push in the first window only.
        let pushes = app.buttons.matching(identifier: "push").allElementsBoundByIndex
        finding("D push buttons=\(pushes.count)")
        pushes.first?.tap()
        sleep(1)
        finding("D after push in one window: \(states(app))")
        shot("D-2-push-one-window")

        // A link with no window preference.
        XCUIDevice.shared.system.open(URL(string: "spike://open?path=X,Y")!)
        sleep(3)
        finding("D after plain link: \(states(app))")
        shot("D-3-plain-link")

        // A link that prefers window 2, then one that prefers window 1.
        XCUIDevice.shared.system.open(URL(string: "spike://open?window=2&path=W2")!)
        sleep(3)
        finding("D after window=2 link: \(states(app))")
        XCUIDevice.shared.system.open(URL(string: "spike://open?window=1&path=W1")!)
        sleep(3)
        finding("D after window=1 link: \(states(app))")
        shot("D-4-targeted-links")

        // Relaunch: does each window come back with its own state?
        app.terminate()
        sleep(2)
        app.launch()
        sleep(4)
        finding("D after relaunch: windows=\(app.windows.count) states=\(states(app))")
        shot("D-5-relaunch")
    }
}
