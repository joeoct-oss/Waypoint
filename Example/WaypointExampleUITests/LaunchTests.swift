//
//  LaunchTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The example app's journeys from launch (splash, sign in, the main tabs, the Lab under settings) and the
// Navigation Lab's entry points: both branches, every flow of both kinds, and the launch arguments that
// open an entry directly.
@MainActor
final class LaunchTests: XCTestCase {
    private static let timeout: TimeInterval = 5
    private static let shopTitle = "Shop"
    private static let accountTitle = "Account"

    func testLaunchShowsSplashThenSignIn() {
        let app = ExampleApp.launch()

        let splash = app.descendants(matching: .any)[Identifiers.splash]
        XCTAssertTrue(splash.waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(app.buttons[Identifiers.signInButton].waitForExistence(timeout: Self.timeout))
    }

    func testSignInLandsOnShop() {
        let app = ExampleApp.launch()
        let signIn = app.buttons[Identifiers.signInButton]
        XCTAssertTrue(signIn.waitForExistence(timeout: Self.timeout))

        signIn.tap()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: Self.timeout))
    }

    func testSettingsOpensNavigationLab() {
        let app = ExampleApp.launch(signedIn: true)
        let accountTab = app.tabBars.buttons[Self.accountTitle]
        XCTAssertTrue(accountTab.waitForExistence(timeout: Self.timeout))

        accountTab.tap()
        tapWhenReady(app.buttons[Identifiers.settingsButton])
        tapWhenReady(app.buttons[Identifiers.labButton])

        XCTAssertTrue(app.buttons[Identifiers.branch(.swiftUI)].waitForExistence(timeout: Self.timeout))
    }

    func testLabShowsBothBranches() {
        let app = ExampleApp.launch(lab: true)

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
        let app = ExampleApp.launch(lab: true)

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
            XCTAssertTrue(reveal(button, in: app), "missing \(Identifiers.entry(entry))")
        }
    }

    private func assertEntryOpensPlaceholder(
        _ entry: FlowEntry,
        in app: XCUIApplication
    ) {
        let button = app.buttons[Identifiers.entry(entry)]
        XCTAssertTrue(reveal(button, in: app), "missing \(Identifiers.entry(entry))")
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

    private func tapWhenReady(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: Self.timeout))
        element.tap()
    }

    private func goBack(in app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    // Lists build rows lazily, so a row below the fold exists only after scrolling to it.
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) -> Bool {
        _ = element.waitForExistence(timeout: Self.timeout)
        for _ in 0..<4 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }
}
