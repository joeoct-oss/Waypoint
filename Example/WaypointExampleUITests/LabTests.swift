//
//  LabTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The Navigation Lab's entry points: both branches, every flow of both kinds, and the launch
// arguments that open an entry directly.
@MainActor
final class LabTests: XCTestCase {
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
}
