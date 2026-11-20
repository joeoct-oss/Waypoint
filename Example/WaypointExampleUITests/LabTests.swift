//
//  LabTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The Navigation Lab's entry points: both branches, every flow of both kinds, the launch arguments
// that open an entry directly, the Detail push flow, which runs for real, and the Lab tools: the
// event log and the navigation tree.
@MainActor
final class LabTests: XCTestCase {
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
            for entry in FlowEntry.entries(in: branch) where !entry.isRunnable {
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

        app.openLabTool(.eventLog)

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

    // TB-02: a product, then the cart, pushed in order; back pops one screen at a time.
    func testDetailPushAndBack() {
        let app = openDetailPush()

        app.buttons[Identifiers.product(id: 1)].tap()
        let product = app.descendants(matching: .any)[Identifiers.detailProduct]
        XCTAssertTrue(product.waitForExistence(timeout: UITestSteps.timeout))

        app.buttons[Identifiers.detailAddToCart].tap()
        let cart = app.descendants(matching: .any)[Identifiers.detailCart]
        XCTAssertTrue(cart.waitForExistence(timeout: UITestSteps.timeout))

        app.goBack()
        XCTAssertTrue(cart.waitForNonExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(product.exists, "back should pop the cart only")
    }

    // TB-03: Back to cart on a product with no cart under it recovers with `.popToRoot`, lands on
    // the shop list and says so in the toast.
    func testPopToMissingRouteRecovers() {
        let app = openDetailPush()

        app.buttons[Identifiers.product(id: 1)].tap()
        let backToCart = app.buttons[Identifiers.detailBackToCart]
        XCTAssertTrue(app.reveal(backToCart))
        backToCart.tap()

        let product = app.descendants(matching: .any)[Identifiers.detailProduct]
        XCTAssertTrue(product.waitForNonExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.buttons[Identifiers.product(id: 1)].exists, "should land on the shop list")

        let toast = app.descendants(matching: .any)[Identifiers.recoveredToast]
        XCTAssertTrue(toast.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(
            toast.label.contains("recovered routeNotInPath by=popToRoot"),
            "toast says \(toast.label)"
        )
    }

    // Opens the SwiftUI branch's Detail push entry and waits for its shop list.
    private func openDetailPush() -> XCUIApplication {
        let app = ExampleApp.launch(lab: true)
        open(.swiftUI, in: app)
        let button = app.buttons[Identifiers.entry(.detailPush)]
        XCTAssertTrue(app.reveal(button), "missing \(Identifiers.entry(.detailPush))")
        button.tap()
        let firstProduct = app.buttons[Identifiers.product(id: 1)]
        XCTAssertTrue(firstProduct.waitForExistence(timeout: UITestSteps.timeout))
        return app
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
