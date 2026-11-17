import XCTest

/// Spike A: the container in every host, with both renderers, and both kinds of destinations.
final class ContainerTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func run(host: String, renderer: String, extra: [String] = []) {
        let app = launch(["-scenario", "a", "-host", host, "-renderer", renderer] + extra)
        let tag = "A-\(host)-\(renderer)\(extra.joined())"
        if ["uikitPresent", "foreignNav", "swiftuiNested"].contains(host) {
            tap(app, "openFlow")
            sleep(1)
        }
        XCTAssertTrue(app.buttons["pushProduct"].waitForExistence(timeout: 5))
        finding("\(tag) root: \(navigationBarSummary(app)) header=\(app.staticTexts["host.header"].exists)")
        shot("\(tag)-1-root")

        tap(app, "pushProduct")
        sleep(1)
        let share = app.buttons["toolbar.share"].exists || app.buttons["Share"].exists
        finding("\(tag) SwiftUI destination: \(navigationBarSummary(app)) shareButton=\(share) state=\(state(app))")
        shot("\(tag)-2-swiftui-destination")

        tap(app, "pushLegacy")
        sleep(1)
        let edit = app.buttons["toolbar.Edit"].exists || app.buttons["Edit"].exists
        if edit {
            app.buttons["Edit"].firstMatch.tap()
        }
        let titleShown = app.navigationBars.staticTexts["L2"].exists || app.navigationBars["L2"].exists
        finding("\(tag) UIKit destination: \(navigationBarSummary(app)) editButton=\(edit) titleL2=\(titleShown) state=\(state(app))")
        shot("\(tag)-3-uikit-destination")

        swipeBack(app)
        sleep(1)
        finding("\(tag) after swipe back: \(navigationBarSummary(app)) state=\(state(app))")

        // The back button is what VoiceOver users reach first; check it is there and labelled.
        let back = app.navigationBars.buttons.element(boundBy: 0)
        finding("\(tag) back button: exists=\(back.exists) label=\(back.exists ? back.label : "-")")
        if back.exists { back.tap() }
        sleep(1)
        finding("\(tag) after back button: state=\(state(app)) notes=\(notes(app))")

        var issues: [String] = []
        if #available(iOS 17.0, *) {
            try? app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion, .elementDetection, .trait]) { issue in
                issues.append("\(issue.auditType.rawValue):\(issue.element?.identifier ?? issue.element?.label ?? "?")")
                return true
            }
        }
        finding("\(tag) accessibility audit: \(issues.count) issue(s) \(issues.prefix(6))")
    }

    func testUIKitChildSwiftUI() { run(host: "uikitChild", renderer: "swiftUI") }
    func testUIKitChildUIKit() { run(host: "uikitChild", renderer: "uiKit") }
    func testUIKitChildSwiftUIRawBridge() { run(host: "uikitChild", renderer: "swiftUI", extra: ["-rawBridge"]) }
    func testUIKitPresentSwiftUI() { run(host: "uikitPresent", renderer: "swiftUI") }
    func testUIKitPresentUIKit() { run(host: "uikitPresent", renderer: "uiKit") }
    func testSwiftUIHostSwiftUI() { run(host: "swiftuiHost", renderer: "swiftUI") }
    func testSwiftUIHostUIKit() { run(host: "swiftuiHost", renderer: "uiKit") }
    func testTabsBoth() { run(host: "uikitTabs", renderer: "swiftUI") }
    func testForeignNavSwiftUI() { run(host: "foreignNav", renderer: "swiftUI") }
    func testForeignNavUIKit() { run(host: "foreignNav", renderer: "uiKit") }
    func testSwiftUINestedSwiftUI() { run(host: "swiftuiNested", renderer: "swiftUI") }
    func testSwiftUINestedUIKit() { run(host: "swiftuiNested", renderer: "uiKit") }

    /// The presented container: swipe down is reported back.
    func testPresentedSwipeDown() {
        for renderer in ["swiftUI", "uiKit"] {
            let app = launch(["-scenario", "a", "-host", "uikitPresent", "-renderer", renderer])
            tap(app, "openFlow")
            sleep(1)
            app.swipeDown(velocity: .fast)
            sleep(1)
            finding("A-present-\(renderer) after swipe down: openFlow visible=\(app.buttons["openFlow"].isHittable)")
        }
    }
}
