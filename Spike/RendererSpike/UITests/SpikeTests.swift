//
//  SpikeTests.swift
//  RendererSpike (#250, throwaway)
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

/// The renderer comes from `TEST_RUNNER_RENDERER` (swiftUI or uiKit).
final class SpikeTests: XCTestCase {
    private var app: XCUIApplication!

    private var renderer: String {
        ProcessInfo.processInfo.environment["RENDERER"] ?? "swiftUI"
    }

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-renderer", renderer, "-scenario", scenario] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["root-A"].waitForExistence(timeout: 10), "root not shown")
    }

    // MARK: Helpers

    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "no control \(id)")
        button.tap()
    }

    private var modelPath: [Int] {
        let label = app.staticTexts["modelPath"].label
        return label.dropFirst("path:".count).split(separator: ",").compactMap { Int($0) }
    }

    private func settle(_ seconds: TimeInterval = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func waitForModel(_ expected: [Int], file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(5)
        while modelPath != expected, Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertEqual(modelPath, expected, "model path", file: file, line: line)
    }

    private func assertShown(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 5),
            "\(title) not shown; bars: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier))",
            file: file, line: line
        )
    }

    private func title(_ number: Int?) -> String {
        number.map { "Screen \($0)" } ?? "Root"
    }

    private func tapBack(from title: String) {
        let bar = app.navigationBars[title]
        let back = bar.buttons["BackButton"]
        if back.exists { back.tap() } else { bar.buttons.element(boundBy: 0).tap() }
    }

    /// Walks back from the top to the root with the back button, checking at
    /// every level that the screen shown and the model agree. This also checks
    /// that user pops reach the model.
    private func assertStackAgrees(_ expected: [Int], file: StaticString = #filePath, line: UInt = #line) {
        settle()
        waitForModel(expected, file: file, line: line)
        var remaining = expected
        while let top = remaining.last {
            assertShown(title(top), file: file, line: line)
            tapBack(from: title(top))
            remaining.removeLast()
            settle(0.9)
            waitForModel(remaining, file: file, line: line)
        }
        assertShown("Root", file: file, line: line)
    }

    private func edgeSwipe(to fraction: CGFloat, velocity: XCUIGestureVelocity, hold: TimeInterval) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: hold)
    }

    func testZDump() {
        app = XCUIApplication()
        app.launchArguments = ["-renderer", renderer, "-scenario", "S1"]
        app.launch()
        settle(2)
        print("DUMP1", app.staticTexts.matching(identifier: "envValue").allElementsBoundByIndex.map(\.label))
        print("DUMPB", app.buttons.matching(identifier: "env").allElementsBoundByIndex.map { "\($0.label) \($0.frame) \($0.isHittable)" })
        app.buttons["env"].tap()
        settle(2)
        print("DUMP2", app.staticTexts.matching(identifier: "envValue").allElementsBoundByIndex.map(\.label), app.staticTexts["obsValue"].label)
    }

    // MARK: S scenarios

    func testS1PushOne() {
        launch("S1")
        tap("push1")
        assertShown("Screen 1")
        assertStackAgrees([1])
    }

    func testS2PushThree() {
        launch("S2")
        tap("push3")
        assertShown("Screen 3")
        assertStackAgrees([1, 2, 3])
    }

    func testS3PopMidTransition() {
        launch("S3")
        tap("pushMid")
        settle(2)
        waitForModel([])
        assertShown("Root")
        XCTAssertFalse(app.navigationBars["Screen 1"].exists, "Screen 1 still shown")
    }

    func testS4SwipeCancelThenSwipe() {
        launch("S4")
        tap("push1")
        assertShown("Screen 1")
        settle()
        edgeSwipe(to: 0.35, velocity: 150, hold: 0.4)
        settle()
        assertShown("Screen 1")
        waitForModel([1])
        edgeSwipe(to: 0.95, velocity: .fast, hold: 0)
        settle()
        if app.navigationBars["Screen 1"].exists {
            edgeSwipe(to: 0.95, velocity: 800, hold: 0)
            settle()
        }
        assertShown("Root")
        waitForModel([])
    }

    func testS5ReplaceInOneStep() {
        launch("S5")
        tap("push3")
        assertShown("Screen 3")
        settle()
        tap("replace")
        assertShown("Screen 4")
        assertStackAgrees([4])
    }

    func testS6PopToRoot() {
        launch("S6")
        tap("push3")
        assertShown("Screen 3")
        settle()
        tap("popRoot")
        settle()
        assertShown("Root")
        waitForModel([])
        XCTAssertFalse(app.navigationBars["Screen 3"].exists)
    }

    func testS7NestedSheets() {
        launch("S7")
        tap("push1")
        assertShown("Screen 1")
        settle()
        tap("sheet")
        XCTAssertTrue(app.staticTexts["sheet-1"].waitForExistence(timeout: 5), "sheet 1")
        tap("openSheet2")
        XCTAssertTrue(app.staticTexts["sheet-2"].waitForExistence(timeout: 5), "sheet 2")
        settle()
        tap("dismissSheet2")
        settle()
        XCTAssertFalse(app.staticTexts["sheet-2"].exists, "sheet 2 still shown")
        XCTAssertTrue(app.staticTexts["sheet-1"].exists, "sheet 1 gone with sheet 2")
        tap("dismissSheet1")
        settle()
        XCTAssertFalse(app.staticTexts["sheet-1"].exists, "sheet 1 still shown")
        assertStackAgrees([1])
    }

    func testS8TabSwitchKeepsStack() {
        launch("S8")
        tap("push3")
        assertShown("Screen 3")
        settle()
        app.tabBars.buttons["Second"].tap()
        assertShown("Second Root")
        settle(0.6)
        app.tabBars.buttons["First"].tap()
        assertShown("Screen 3")
        assertStackAgrees([1, 2, 3])
    }

    func testS9Stress() {
        launch("S9")
        tap("stress")
        settle(3)
        // 14 pushes and 6 pops: the model keeps 8 screens.
        XCTAssertEqual(modelPath.count, 8, "model \(modelPath)")
        assertStackAgrees(modelPath)
    }

    // MARK: E checks

    private func value(_ id: String) -> String {
        let element = app.staticTexts[id].firstMatch
        _ = element.waitForExistence(timeout: 3)
        return element.exists ? element.label : "<none>"
    }

    private func pushedEnvironment(_ scenario: String, extra: [String] = []) -> (String, String) {
        launch(scenario, extra: extra)
        tap("push1")
        assertShown("Screen 1")
        settle()
        return (value("envValue"), value("obsValue"))
    }

    func testE1EnvironmentKey() {
        let (env, _) = pushedEnvironment("E1")
        XCTAssertEqual(env, "env-outer")
        tap("env")
        settle()
        XCTAssertEqual(value("envValue"), "env-outer2", "change above the renderer not seen")
    }

    func testE2ObservableObject() {
        let (_, obs) = pushedEnvironment("E2")
        XCTAssertEqual(obs, "obs-red")
        tap("theme")
        settle()
        XCTAssertEqual(value("obsValue"), "obs-blue", "change did not redraw")
    }

    func testE3RendererValue() {
        launch("E3")
        XCTAssertEqual(value("routerValue"), "router-A", "root")
        tap("push3")
        assertShown("Screen 3")
        settle()
        XCTAssertEqual(value("routerValue"), "router-A", "screen 3")
        tapBack(from: "Screen 3")
        assertShown("Screen 2")
        settle()
        XCTAssertEqual(value("routerValue"), "router-A", "screen 2")
    }

    func testE4WholeEnvironment() {
        let (env, obs) = pushedEnvironment("E4")
        XCTAssertEqual(env, "env-outer")
        XCTAssertEqual(obs, "obs-red")
        XCTAssertEqual(value("routerValue"), "router-A")
        tap("theme")
        tap("env")
        settle()
        XCTAssertEqual(value("obsValue"), "obs-blue", "observable change did not redraw")
        XCTAssertEqual(value("envValue"), "env-outer2", "key change not seen")
    }

    /// Reference only: what a hosted screen sees with no forwarding.
    func testE0NoForwarding() {
        let (env, obs) = pushedEnvironment("E0", extra: ["-envMode", "none"])
        print("E0 \(renderer): \(env) \(obs) \(value("routerValue"))")
        tap("theme")
        tap("env")
        settle()
        print("E0 \(renderer) after change: \(value("envValue")) \(value("obsValue"))")
    }

    // MARK: C checks

    /// UIKit only: SwiftUI chrome with no help from the renderer.
    func testC1BridgedTitle() {
        launch("C1", extra: ["-uikitChrome", "swiftUI"])
        let rootBar = app.navigationBars.firstMatch
        print("C1B \(renderer) root bar: \(rootBar.identifier) texts \(rootBar.staticTexts.allElementsBoundByIndex.map(\.label))")
        tap("push1")
        settle()
        let bar = app.navigationBars.firstMatch
        print("C1B \(renderer) pushed bar: \(bar.identifier) texts \(bar.staticTexts.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(app.navigationBars["Screen 1"].exists, "SwiftUI title not bridged")
    }

    /// UIKit only: are SwiftUI toolbar items bridged without renderer help?
    func testC2BridgedToolbar() {
        launch("C2", extra: ["-uikitChrome", "swiftUI"])
        tap("pushToolbar")
        settle()
        XCTAssertTrue(app.buttons["leadItem"].exists && app.buttons["trailItem"].exists, "toolbar not bridged")
    }

    func testC1Title() {
        launch("C1")
        tap("push1")
        assertShown("Screen 1")
        XCTAssertTrue(app.navigationBars["Screen 1"].staticTexts["Screen 1"].exists, "title text not in bar")
    }

    func testC2Toolbar() {
        launch("C2")
        tap("pushToolbar")
        assertShown("Screen 1")
        settle()
        let lead = app.buttons["leadItem"].firstMatch
        let trail = app.buttons["trailItem"].firstMatch
        XCTAssertTrue(lead.exists && lead.isHittable, "leading item")
        XCTAssertTrue(trail.exists && trail.isHittable, "trailing item")
        lead.tap()
        trail.tap()
        trail.tap()
        XCTAssertEqual(value("toolbarTaps"), "taps-1-2")
        let bar = app.navigationBars["Screen 1"]
        print("C2 \(renderer) bar buttons: \(bar.buttons.allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)" })")
        XCTAssertTrue(bar.buttons["BackButton"].exists || bar.buttons.count >= 3, "back button missing")
    }

    func testC3BackTitle() {
        launch("C3")
        tap("push1")
        assertShown("Screen 1")
        settle()
        tap("push1")
        assertShown("Screen 2")
        settle()
        let bar = app.navigationBars["Screen 2"]
        let back = bar.buttons["BackButton"].exists ? bar.buttons["BackButton"] : bar.buttons.element(boundBy: 0)
        print("C3 \(renderer) back label: '\(back.label)' id '\(back.identifier)'")
        XCTAssertTrue(["Screen 1", "Back"].contains(back.label), "back label '\(back.label)'")
    }

    func testC4Searchable() {
        launch("C4")
        tap("pushSearch")
        assertShown("Screen 1")
        settle()
        let field = app.searchFields.firstMatch
        if !field.exists {
            // The field may sit under the bar until the list is pulled down.
            app.staticTexts["item-Apple"].firstMatch.swipeDown()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 3), "no search field")
        field.tap()
        field.typeText("ban")
        settle(0.6)
        XCTAssertTrue(app.staticTexts["item-Banana"].exists, "Banana gone")
        XCTAssertFalse(app.staticTexts["item-Apple"].exists, "Apple not filtered")
    }

    func testC5TabBarHidden() {
        launch("C5")
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists && tabBar.isHittable, "tab bar on root")
        let rootFrame = tabBar.frame
        tap("push1")
        assertShown("Screen 1")
        settle()
        XCTAssertFalse(tabBar.exists && tabBar.isHittable, "tab bar shown on pushed screen")
        tapBack(from: "Screen 1")
        assertShown("Root")
        settle()
        XCTAssertTrue(tabBar.exists && tabBar.isHittable, "tab bar not back after pop")
        XCTAssertEqual(tabBar.frame, rootFrame, "tab bar moved")
    }

    func testC6TitleModes() {
        launch("C6")
        settle()
        let rootHeight = app.navigationBars["Root"].frame.height
        tap("push1")
        assertShown("Screen 1")
        settle()
        let pushedHeight = app.navigationBars["Screen 1"].frame.height
        tapBack(from: "Screen 1")
        assertShown("Root")
        settle()
        let backHeight = app.navigationBars["Root"].frame.height
        print("C6 \(renderer) heights root \(rootHeight) pushed \(pushedHeight) back \(backHeight)")
        XCTAssertGreaterThan(rootHeight, pushedHeight + 20, "root not large")
        XCTAssertEqual(backHeight, rootHeight, accuracy: 1, "root not large again after pop")
    }
}
