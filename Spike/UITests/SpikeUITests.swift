import XCTest

/// Drives the four spike cases and records what the router and the screen say.
/// Each check prints a FINDING line; assertions only stop on outright breakage.
@MainActor
class SpikeTestCase: XCTestCase {
    var app: XCUIApplication!
    var extraArguments: [String] { [] }

    override func setUp() async throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += extraArguments
        app.launch()
    }

    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let candidates = app.buttons.matching(identifier: id).allElementsBoundByIndex
        guard let button = candidates.first(where: { $0.isHittable }) else {
            XCTFail("no hittable button \(id)", file: file, line: line)
            return
        }
        button.tap()
    }

    var state: String { app.staticTexts.matching(identifier: "state").firstMatch.label }
    var appears: String { app.staticTexts.matching(identifier: "appears").firstMatch.label }
    var notes: String { app.staticTexts.matching(identifier: "notes").firstMatch.label }

    var navTitle: String {
        let bars = app.navigationBars.allElementsBoundByIndex.filter { $0.isHittable }
        return bars.last?.identifier ?? "?"
    }

    func settle() { _ = app.wait(for: .runningForeground, timeout: 1); Thread.sleep(forTimeInterval: 1.0) }

    func record(_ label: String) {
        let line = "FINDING \(name) | \(label) | title=\(navTitle) | \(state) | \(appears) | \(notes)"
        print(line)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func swipeBack() {
        // Start on the screen edge itself: iOS 17 ignores a drag that starts a few points in.
        // iOS 17 needs a fast drag; on iOS 27 a fast drag can cancel inside a UIKit sheet,
        // so a slower drag follows when the first one did not pop.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let before = navTitle
        for velocity: XCUIGestureVelocity in [.fast, 800] {
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: 0)
            settle()
            if navTitle != before { return }
        }
    }

    func swipeDownSheet() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.05, thenDragTo: end)
        settle()
    }

    func longPressBackAndChoose(_ title: String) {
        let back = app.navigationBars.allElementsBoundByIndex.filter { $0.isHittable }.last?.buttons.firstMatch
        back?.press(forDuration: 1.2)
        settle()
        let item = app.buttons[title].exists ? app.buttons[title] : app.menuItems[title]
        if item.exists { item.tap() } else { print("FINDING \(name) | long-press menu item \(title) not found") }
        settle()
    }

    func selectTab(_ label: String) {
        app.tabBars.buttons[label].firstMatch.tap()
        settle()
    }

    // Case 1: stack sync, including the one-animation multi-step push and pop.
    func runStackCase(tab: String) {
        selectTab(tab)
        tap("clearLog"); settle()
        tap("pushToE"); settle()
        record("pushToE")
        XCTAssertEqual(navTitle, "E")
        tap("clearLog"); settle()
        app.navigationBars["E"].buttons.firstMatch.tap(); settle()
        record("back from E")
        XCTAssertEqual(navTitle, "D")
        tap("popToB"); settle()
        record("popToB")
        XCTAssertEqual(navTitle, "B")
        swipeBack()
        record("swipe back from B")
        XCTAssertEqual(navTitle, "A")
        tap("pushToE"); settle()
        tap("clearLog"); settle()
        longPressBackAndChoose("B")
        record("long-press back menu to B")
        tap("pushProduct"); settle()
        record("push product")
        tap("popToRoot"); settle()
        record("popToRoot")
        XCTAssertEqual(navTitle, "A")
    }

    // Case 2: sheet with its own stack inside a tab, interactive dismissal, tab stacks kept.
    func runSheetCase(tab: String, present: String) {
        selectTab(tab)
        tap("pushNext"); settle()
        tap(present); settle()
        tap("pushToE"); settle()
        record("sheet pushToE (\(present))")
        swipeBack()
        record("sheet swipe back")
        XCTAssertEqual(navTitle, "D")
        swipeDownSheet()
        record("sheet swipe down")
        selectTab("SwiftUI B")
        tap("pushNext"); settle()
        selectTab(tab)
        record("tab round trip keeps stack")
        tap("popToRoot"); settle()
    }
}

final class NavigationPathModeTests: SpikeTestCase {
    func testCase1SwiftUIStack() { runStackCase(tab: "SwiftUI A") }
    func testCase1UIKitStack() { runStackCase(tab: "UIKit C") }
    func testCase2SheetInSwiftUITab() { runSheetCase(tab: "SwiftUI A", present: "presentSwiftUI") }
    func testCase3SwiftUIPresentsUIKit() { runSheetCase(tab: "SwiftUI A", present: "presentUIKit") }
    func testCase3UIKitPresentsSwiftUI() { runSheetCase(tab: "UIKit C", present: "presentSwiftUI") }
    func testCase3UIKitPresentsUIKit() { runSheetCase(tab: "UIKit C", present: "presentUIKit") }

    // Case 4: one link selects a tab, dismisses a sheet and sets a path in one change.
    func testCase4DeepLinkFromSheet() {
        selectTab("SwiftUI A")
        tap("pushNext"); settle()
        tap("presentSwiftUI"); settle()
        tap("pushNext"); settle()
        tap("clearLog"); settle()
        tap("linkB"); settle()
        record("linkB from sheet in tab A")
        XCTAssertEqual(navTitle, "D")
        app.navigationBars["D"].buttons.firstMatch.tap(); settle()
        record("back after linkB")
    }

    func testCase4DeepLinkSameTabWithSheet() {
        selectTab("SwiftUI A")
        tap("pushToE"); settle()
        tap("presentUIKit"); settle()
        tap("clearLog"); settle()
        tap("linkA"); settle()
        record("linkA from UIKit sheet over tab A at E")
        XCTAssertEqual(navTitle, "C")
    }

    func testCase4DeepLinkFromURL() {
        selectTab("UIKit C")
        tap("presentSwiftUI"); settle()
        tap("clearLog"); settle()
        app.open(URL(string: "spike://open?tab=b&path=B,C,D")!)
        settle()
        record("URL linkB from sheet over UIKit tab")
        XCTAssertEqual(navTitle, "D")
    }

    func testCase4DeepLinkIntoUIKitTab() {
        selectTab("SwiftUI A")
        tap("presentSwiftUI"); settle()
        tap("clearLog"); settle()
        app.open(URL(string: "spike://open?tab=c&path=B,C,D")!)
        settle()
        record("URL link into UIKit tab")
        XCTAssertEqual(navTitle, "D")
    }
}

final class AnyRoutePathModeTests: SpikeTestCase {
    override var extraArguments: [String] { ["-anyRoutePath"] }
    func testCase1SwiftUIStack() { runStackCase(tab: "SwiftUI A") }
    func testCase2SheetInSwiftUITab() { runSheetCase(tab: "SwiftUI A", present: "presentSwiftUI") }
}

final class RapidTests: SpikeTestCase {
    /// Changes that land while a push or pop animation is still running.
    func runRapid(tab: String) {
        selectTab(tab)
        let button = app.buttons.matching(identifier: "pushNext").allElementsBoundByIndex.first { $0.isHittable }!
        let point = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        point.tap(); point.tap(); point.tap()
        settle()
        record("three fast pushNext taps")
        tap("pushToE")
        app.open(URL(string: "spike://open?tab=\(tab == "UIKit C" ? "c" : "a")&path=B")!)
        settle()
        record("link to B during pushToE animation")
    }

    func testRapidSwiftUI() { runRapid(tab: "SwiftUI A") }
    func testRapidUIKit() { runRapid(tab: "UIKit C") }
}

final class ProbeTests: SpikeTestCase {
    func testLongPressMenuDump() {
        for tab in ["SwiftUI A", "UIKit C"] {
            selectTab(tab)
            tap("pushToE"); settle()
            let back = app.navigationBars["E"].buttons.firstMatch
            print("PROBE back button: \(back.label) id=\(back.identifier)")
            let center = back.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.press(forDuration: 2.5)
            Thread.sleep(forTimeInterval: 1.0)
            print("PROBE \(tab) tree after long press:\n\(app.debugDescription)")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "menu \(tab)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
            settle()
            tap("popToRoot"); settle()
        }
    }

    /// Slow sequence for a screen recording: pushToE, back, popToB, in both renderers.
    func testRecordSequence() {
        for tab in ["SwiftUI A", "UIKit C"] {
            selectTab(tab)
            Thread.sleep(forTimeInterval: 2)
            tap("pushToE"); Thread.sleep(forTimeInterval: 2)
            app.navigationBars["E"].buttons.firstMatch.tap(); Thread.sleep(forTimeInterval: 2)
            tap("popToB"); Thread.sleep(forTimeInterval: 2)
            tap("popToRoot"); Thread.sleep(forTimeInterval: 2)
        }
    }
}
