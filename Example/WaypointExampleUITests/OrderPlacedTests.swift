//
//  OrderPlacedTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// Order placed runs on checkout's Waypoint stack (#281): placing the order replaces the steps with
// Order placed in one `setPath`, which the Lab's event log shows as one line with no Review left
// in the stack, and Continue shopping closes checkout and leaves the cart at its root.
@MainActor
final class OrderPlacedTests: XCTestCase {
    private static let shopTitle = "Shop"
    private static let cartTitle = "Cart"
    private static let productID = 1
    // The setPath line: Order placed in the stack, with the steps it replaced gone.
    private static let replacedPath = NSPredicate(
        format: "label CONTAINS 'set' AND label CONTAINS 'Order placed' AND NOT (label CONTAINS 'Review')"
    )

    func testPlacingOrderReplacesCheckoutPath() {
        let app = placeOrder()
        app.buttons[Identifiers.continueShopping].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))

        app.openLabTool(.eventLog)
        let entry = app.descendants(matching: .any).matching(Self.replacedPath).firstMatch
        XCTAssertTrue(app.reveal(entry), "the event log doesn't show the steps replaced in one change")
    }

    func testContinueShoppingResetsCart() {
        let app = placeOrder()
        let placed = app.descendants(matching: .any)[Identifiers.orderPlaced]
        app.buttons[Identifiers.continueShopping].tapWhenReady()
        XCTAssertTrue(placed.waitForNonExistence(timeout: UITestSteps.timeout), "checkout stayed open")

        app.openTab(Self.cartTitle)
        XCTAssertTrue(app.navigationBars[Self.cartTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.buttons[Identifiers.browseShop].exists, "the cart isn't empty at its root")
        XCTAssertFalse(app.buttons[Identifiers.checkout].exists, "the cart kept the order's products")
    }

    // Adds the lamp, checks out with the first address and the saved card, and places the order.
    private func placeOrder() -> XCUIApplication {
        let app = ExampleApp.launch(signedIn: true)
        app.buttons[Identifiers.product(id: Self.productID)].tapWhenReady()
        app.buttons[Identifiers.addToCart].tapWhenReady()
        app.buttons[Identifiers.checkout].tapWhenReady()
        app.buttons[Identifiers.continueToPayment].tapWhenReady()
        app.buttons[Identifiers.continueToReview].tapWhenReady()
        app.buttons[Identifiers.placeOrder].tapWhenReady()
        let placed = app.descendants(matching: .any)[Identifiers.orderPlaced]
        XCTAssertTrue(placed.waitForExistence(timeout: UITestSteps.timeout), "Order placed didn't show")
        return app
    }
}
