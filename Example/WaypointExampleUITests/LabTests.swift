//
//  LabTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The Navigation Lab's entry points: both branches, every flow of both kinds, the launch arguments
// that open an entry directly, and the Lab tools: the event log and the navigation tree.
@MainActor
final class LabTests: XCTestCase {
    private static let accountTitle = "Account"
    private static let lampID = 1
    private static let missingRouteName = "ProductReviewsRoute"
    // How the tree names the route of the screen it is shown on: the account flow, then the
    // route's case, with its private value folded.
    private static let currentRouteName = "Account: labTool"
    private static let applied = "applied"
    private static let failed = "failed"

    func testLabShowsBothBranches() {
        let app = ExampleApp.launch(lab: true)

        for branch in Branch.allCases {
            let card = app.buttons[Identifiers.branch(branch)]
            XCTAssertTrue(card.waitForExistence(timeout: UITestSteps.timeout), "missing \(branch.rawValue) branch")
        }
    }

    func testEveryEntryOpensItsPlaceholder() {
        let app = ExampleApp.launch(lab: true)

        for branch in Branch.allCases {
            open(branch, in: app)
            for entry in FlowEntry.entries(in: branch) {
                assertEntryOpensPlaceholder(entry, in: app)
            }
            app.goBack()
        }
    }

    func testLaunchHelperOpensFlowDirectly() {
        let app = ExampleApp.launch(
            branch: .uiKit,
            flow: .sheet,
            kind: .swiftUI
        )
        let entry = FlowEntry(
            branch: .uiKit,
            flow: .sheet,
            kind: .swiftUI
        )

        let placeholder = app.otherElements[Identifiers.placeholder(entry)]
        XCTAssertTrue(placeholder.waitForExistence(timeout: UITestSteps.timeout))
    }

    func testEventLogListsOutcomes() {
        let app = ExampleApp.launch(
            signedIn: true,
            missingDestination: true
        )
        app.buttons[Identifiers.product(id: Self.lampID)].tapWhenReady()
        let relatedLink = app.buttons[Identifiers.relatedProduct]
        XCTAssertTrue(app.reveal(relatedLink))
        relatedLink.tap()
        let banner = app.descendants(matching: .any)[Identifiers.navigationIssue]
        XCTAssertTrue(banner.waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        app.goBack()
        XCTAssertTrue(app.waitForTabBar(shown: true))

        openTool(.eventLog, in: app)

        let applied = app.descendants(matching: .any)[Identifiers.eventLogEntry(Self.applied)].firstMatch
        XCTAssertTrue(applied.waitForExistence(timeout: UITestSteps.timeout))
        let failed = app.descendants(matching: .any)[Identifiers.eventLogEntry(Self.failed)].firstMatch
        XCTAssertTrue(app.reveal(failed))
        XCTAssertTrue(failed.label.contains(Self.missingRouteName), failed.label)
    }

    func testNavigationTreeShowsCurrentRoute() {
        let app = ExampleApp.launch(lab: true)

        // The Lab tools sit below the branches and the stories, so the row is scrolled into view
        // before the tap.
        let row = app.buttons[Identifiers.labTool(.navigationTree)]
        XCTAssertTrue(app.reveal(row), "missing \(Identifiers.labTool(.navigationTree))")
        row.tap()

        let tree = app.staticTexts[Identifiers.navigationTree]
        XCTAssertTrue(tree.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(tree.label.contains(Self.currentRouteName), tree.label)
    }

    private func assertEntryOpensPlaceholder(
        _ entry: FlowEntry,
        in app: XCUIApplication
    ) {
        let button = app.buttons[Identifiers.entry(entry)]
        XCTAssertTrue(app.reveal(button), "missing \(Identifiers.entry(entry))")
        button.tap()

        let placeholder = app.otherElements[Identifiers.placeholder(entry)]
        XCTAssertTrue(
            placeholder.waitForExistence(timeout: UITestSteps.timeout),
            "\(Identifiers.entry(entry)) opened nothing"
        )
        app.goBack()
    }

    private func open(
        _ branch: Branch,
        in app: XCUIApplication
    ) {
        let card = app.buttons[Identifiers.branch(branch)]
        XCTAssertTrue(card.waitForExistence(timeout: UITestSteps.timeout))
        card.tap()
    }

    private func openTool(
        _ tool: LabTool,
        in app: XCUIApplication
    ) {
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.settingsButton].tapWhenReady()
        app.buttons[Identifiers.labButton].tapWhenReady()
        let row = app.buttons[Identifiers.labTool(tool)]
        XCTAssertTrue(app.reveal(row), "missing \(Identifiers.labTool(tool))")
        row.tap()
    }
}
