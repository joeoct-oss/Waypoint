//
//  LabSheetTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The Lab's Sheet story runs on Waypoint: each button changes the story's router as
// it is named, which the story's tree and the Lab's event log show, and a full-screen cover opens
// and closes. A level's buttons are found inside that level, because a sheet under another one
// stays in the accessibility tree.
@MainActor
final class LabSheetTests: XCTestCase {
    private static let largeTitle = "Large"
    private static let switchOff = "0"
    // The story names each level it presents after its route, so the tree names a presented level
    // this way and shows nothing like it once every level has closed.
    private static let presentedFlow = "sheetDemo"
    private static let largePresentation = NSPredicate(format: "label CONTAINS 'detents: [large]'")
    private static let levelDismissal = NSPredicate(format: "label CONTAINS 'dismiss' AND label CONTAINS 'sheetDemo'")
    // Dismiss flow on level 2, Dismiss on level 1, then Dismiss all over two levels.
    private static let dismissalCount = 3

    func testLabSheetButtonsChangeRouter() {
        let app = openSheetStory()
        app.segmentedControls[Identifiers.sheetDemoSize].buttons[Self.largeTitle].tapWhenReady()
        let swipe = app.switches[Identifiers.sheetDemoSwipe]
        XCTAssertTrue(swipe.setSwitch(to: Self.switchOff), "the swipe toggle stayed on")

        app.buttons[Identifiers.sheetDemoPresent].tapWhenReady()
        let first = level(1, in: app)
        XCTAssertTrue(first.waitForExistence(timeout: UITestSteps.timeout), "Present sheet opened nothing")
        first.swipeDown(velocity: .fast)
        XCTAssertFalse(first.waitForNonExistence(timeout: UITestSteps.stayTime), "a swipe closed a locked sheet")

        first.buttons[Identifiers.sheetDemoPresentOnTop].tapWhenReady()
        let second = level(2, in: app)
        XCTAssertTrue(second.waitForExistence(timeout: UITestSteps.timeout), "Present on top opened nothing")
        second.buttons[Identifiers.sheetDemoDismissFlow].tapWhenReady()
        XCTAssertTrue(second.waitForNonExistence(timeout: UITestSteps.timeout), "Dismiss flow left level 2 open")
        XCTAssertTrue(first.exists, "Dismiss flow closed level 1 too")

        first.buttons[Identifiers.sheetDemoDismiss].tapWhenReady()
        XCTAssertTrue(first.waitForNonExistence(timeout: UITestSteps.timeout), "Dismiss left level 1 open")
        assertTreeShowsNothingPresented(in: app)

        app.buttons[Identifiers.sheetDemoPresent].tapWhenReady()
        first.buttons[Identifiers.sheetDemoPresentOnTop].tapWhenReady()
        second.buttons[Identifiers.sheetDemoDismissAll].tapWhenReady()
        XCTAssertTrue(second.waitForNonExistence(timeout: UITestSteps.timeout), "Dismiss all left level 2 open")
        XCTAssertTrue(first.waitForNonExistence(timeout: UITestSteps.timeout), "Dismiss all left level 1 open")
        assertTreeShowsNothingPresented(in: app)

        openEventLog(in: app)
        let presentation = app.descendants(matching: .any).matching(Self.largePresentation).firstMatch
        XCTAssertTrue(app.reveal(presentation), "the event log doesn't show the large sheet")
        let dismissals = app.descendants(matching: .any).matching(Self.levelDismissal)
        XCTAssertGreaterThanOrEqual(dismissals.count, Self.dismissalCount, "the event log misses a dismissal")
    }

    func testLabSheetCoverOpensAndCloses() {
        let app = openSheetStory()

        app.buttons[Identifiers.sheetDemoCover].tapWhenReady()
        let cover = level(1, in: app)
        XCTAssertTrue(cover.waitForExistence(timeout: UITestSteps.timeout), "Present cover opened nothing")
        XCTAssertEqual(cover.frame.minY, app.frame.minY, "the cover doesn't fill the screen")
        cover.buttons[Identifiers.sheetDemoDismiss].tapWhenReady()

        XCTAssertTrue(cover.waitForNonExistence(timeout: UITestSteps.timeout), "Dismiss left the cover open")
        assertTreeShowsNothingPresented(in: app)
    }

    // Present right after Dismiss, while the old sheet still slides away, draws the new level, not
    // a blank sheet.
    func testLabSheetPresentsRightAfterDismiss() {
        let app = openSheetStory()
        app.buttons[Identifiers.sheetDemoPresent].tapWhenReady()
        let first = level(1, in: app)
        first.buttons[Identifiers.sheetDemoDismiss].tapWhenReady()

        app.buttons[Identifiers.sheetDemoPresent].tapWhenReady()
        let presentOnTop = level(1, in: app).buttons[Identifiers.sheetDemoPresentOnTop]
        XCTAssertTrue(presentOnTop.waitForExistence(timeout: UITestSteps.timeout), "the new sheet is blank")
    }

    private func openSheetStory() -> XCUIApplication {
        let app = ExampleApp.launch(lab: true)
        let entry = FlowEntry.sheet
        app.buttons[Identifiers.branch(entry.branch)].tapWhenReady()
        let button = app.buttons[Identifiers.entry(entry)]
        XCTAssertTrue(app.reveal(button), "missing \(Identifiers.entry(entry))")
        button.tap()
        XCTAssertTrue(app.buttons[Identifiers.sheetDemoPresent].waitForExistence(timeout: UITestSteps.timeout))
        return app
    }

    private func level(
        _ number: Int,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[Identifiers.sheetDemoLevel(number)]
    }

    // Reads the story router's tree on the story's screen, so the check is on the router.
    private func assertTreeShowsNothingPresented(in app: XCUIApplication) {
        let tree = app.staticTexts[Identifiers.sheetDemoTree]
        XCTAssertTrue(app.reveal(tree), "the story shows no tree")
        XCTAssertFalse(tree.label.contains(Self.presentedFlow), tree.label)
    }

    // Closes the story and opens the Lab's event log.
    private func openEventLog(in app: XCUIApplication) {
        app.buttons[Identifiers.labDemoClose].tapWhenReady()
        app.goBack()
        let row = app.buttons[Identifiers.labTool(.eventLog)]
        XCTAssertTrue(app.reveal(row), "missing \(Identifiers.labTool(.eventLog))")
        row.tap()
    }
}
