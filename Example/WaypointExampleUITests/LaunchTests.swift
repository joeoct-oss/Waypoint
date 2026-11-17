//
//  LaunchTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The example app's launch and entry points: both branches, every flow of both kinds, and the launch
// arguments that open an entry directly.
@MainActor
final class LaunchTests: XCTestCase {
    private static let timeout: TimeInterval = 5

    func testLaunchShowsBothBranches() {
        let app = ExampleApp.launch()

        for branch in Branch.allCases {
            let card = app.buttons[Identifiers.branch(branch)]
            XCTAssertTrue(card.waitForExistence(timeout: Self.timeout), "missing \(branch.rawValue) branch")
        }
    }

    func testSwiftUIBranchListsAllFlows() {
        assertBranchListsAllFlows(.swiftUI)
    }

    func testUIKitBranchListsAllFlows() {
        assertBranchListsAllFlows(.uiKit)
    }

    func testEveryEntryOpensItsPlaceholder() {
        let app = ExampleApp.launch()

        for branch in Branch.allCases {
            open(branch, in: app)
            for entry in FlowEntry.entries(in: branch) {
                assertEntryOpensPlaceholder(entry, in: app)
            }
            goBack(in: app)
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
        XCTAssertTrue(placeholder.waitForExistence(timeout: Self.timeout))
    }

    private func assertBranchListsAllFlows(_ branch: Branch) {
        let app = ExampleApp.launch(branch: branch)

        for entry in FlowEntry.entries(in: branch) {
            let button = app.buttons[Identifiers.entry(entry)]
            XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "missing \(Identifiers.entry(entry))")
        }
    }

    private func assertEntryOpensPlaceholder(
        _ entry: FlowEntry,
        in app: XCUIApplication
    ) {
        let button = app.buttons[Identifiers.entry(entry)]
        XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "missing \(Identifiers.entry(entry))")
        scrollIntoView(button, in: app)
        button.tap()

        let placeholder = app.otherElements[Identifiers.placeholder(entry)]
        XCTAssertTrue(
            placeholder.waitForExistence(timeout: Self.timeout),
            "\(Identifiers.entry(entry)) opened nothing"
        )
        goBack(in: app)
    }

    private func open(
        _ branch: Branch,
        in app: XCUIApplication
    ) {
        let card = app.buttons[Identifiers.branch(branch)]
        XCTAssertTrue(card.waitForExistence(timeout: Self.timeout))
        card.tap()
    }

    private func goBack(in app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func scrollIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        for _ in 0..<3 where !element.isHittable {
            app.swipeUp()
        }
    }
}
