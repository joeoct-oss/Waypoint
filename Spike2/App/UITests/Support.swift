import XCTest

/// Shared helpers for the spike UI tests.
extension XCTestCase {
    func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    func state(_ app: XCUIApplication) -> String {
        let element = app.staticTexts.matching(identifier: "state").firstMatch
        return element.exists ? element.label : "<no state>"
    }

    func notes(_ app: XCUIApplication) -> String {
        let element = app.staticTexts.matching(identifier: "notes").firstMatch
        return element.exists ? element.label : "<no notes>"
    }

    func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 5) {
        let button = app.buttons.matching(identifier: id).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "missing button \(id)")
        button.tap()
    }

    func finding(_ text: String) {
        print("FINDING \(name): \(text)")
    }

    /// Saves a screenshot into SPIKE_SHOTS (a host folder) and attaches it.
    func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let folder = ProcessInfo.processInfo.environment["SPIKE_SHOTS"] ?? "/tmp/spike-shots"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(folder)/\(name).png"))
    }

    /// A drag from the left edge, as the renderer spike learned: start at dx 0, fast, then slower.
    func swipeBack(_ app: XCUIApplication) {
        let before = state(app)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.1)
        sleep(1)
        if state(app) == before {
            print("FINDING swipe back: fast drag did nothing, trying 800 pt/s")
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(800), thenHoldForDuration: 0.1)
            sleep(1)
        }
    }

    func navigationBarSummary(_ app: XCUIApplication) -> String {
        let bars = app.navigationBars.allElementsBoundByIndex
        return "\(bars.count) bar(s): " + bars.map { bar in
            let buttons = bar.buttons.allElementsBoundByIndex.map { $0.label }.joined(separator: "/")
            return "[\(bar.identifier) buttons=\(buttons)]"
        }.joined(separator: " ")
    }
}
