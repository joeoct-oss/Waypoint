//
//  NestedSheetTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// A sheet over a sheet, and every way Waypoint closes presentations (planning #413). Shop's wish
// list sheet asks a guest to sign in over it, two levels deep: Cancel closes one level, and Done on
// Signed in closes both in one change with `dismissAll`. The saved sheet's Close uses
// `@DismissFlow`, and the wish list's Done uses `dismissFlow`. After each close the Lab's
// navigation tree shows nothing presented, and the event log shows the close.
@MainActor
final class NestedSheetTests: XCTestCase {
    private static let shopTitle = "Shop"
    private static let email = "nova@example.com"
    private static let password = "orbit-2026"
    private static let suggestedID = 1
    private static let savedID = 2
    // The tree names each presented flow on a line that starts with its style.
    private static let presentedMark = "sheet"
    private static let wishlistClose = NSPredicate(format: "label CONTAINS 'dismiss' AND label CONTAINS 'wishlist'")
    private static let savedClose = NSPredicate(format: "label CONTAINS 'dismiss' AND label CONTAINS 'saved'")
    // The accounts flow is `AuthCoordinator`'s, so the log names it `auth`.
    private static let signInClose = NSPredicate(format: "label CONTAINS 'dismiss' AND label CONTAINS 'auth'")

    func testSignInOpensOverWishlist() {
        let app = ExampleApp.launch()
        openWishlist(in: app)
        app.buttons[Identifiers.wishlistSave(id: Self.suggestedID)].tapWhenReady()

        let signIn = app.buttons[Identifiers.signInButton]
        XCTAssertTrue(signIn.waitForExistence(timeout: UITestSteps.timeout), "Save didn't ask the guest to sign in")
        app.buttons[Identifiers.authCancel].tapWhenReady()

        // Cancel closes only the accounts flow, so the wish list it opened over is still there.
        XCTAssertTrue(signIn.waitForNonExistence(timeout: UITestSteps.timeout), "Cancel left sign in open")
        let wishlist = app.descendants(matching: .any)[Identifiers.wishlist]
        XCTAssertTrue(wishlist.waitForExistence(timeout: UITestSteps.timeout), "Cancel closed the wish list too")
        XCTAssertTrue(app.buttons[Identifiers.wishlistSave(id: Self.suggestedID)].exists, "Cancel saved the product")

        // Cancel dismissed the accounts flow on its own, under the name `testDoneClosesAllSheets`
        // looks for.
        app.buttons[Identifiers.wishlistDone].tapWhenReady()
        XCTAssertTrue(wishlist.waitForNonExistence(timeout: UITestSteps.timeout), "Done left the wish list open")
        app.openLabTool(.eventLog)
        let signInEntry = app.descendants(matching: .any).matching(Self.signInClose).firstMatch
        XCTAssertTrue(app.reveal(signInEntry), "the event log doesn't show the accounts flow closing")
    }

    func testDoneClosesAllSheets() {
        let app = ExampleApp.launch()
        openWishlist(in: app)
        app.buttons[Identifiers.wishlistSave(id: Self.suggestedID)].tapWhenReady()
        signIn(in: app)

        let done = app.buttons[Identifiers.signedInDone]
        XCTAssertTrue(done.waitForExistence(timeout: UITestSteps.timeout), "signing in didn't show Signed in")
        app.closeLateSavePasswordOffer()
        done.tap()

        let wishlist = app.descendants(matching: .any)[Identifiers.wishlist]
        XCTAssertTrue(wishlist.waitForNonExistence(timeout: UITestSteps.timeout), "Done left the wish list open")
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))

        // One change closed both: the wish list's dismissal is logged, and the accounts flow left
        // with it instead of being dismissed on its own first.
        app.openLabTool(.eventLog)
        let wishlistEntry = app.descendants(matching: .any).matching(Self.wishlistClose).firstMatch
        XCTAssertTrue(app.reveal(wishlistEntry), "the event log doesn't show the wish list closing")
        let signInEntry = app.descendants(matching: .any).matching(Self.signInClose).firstMatch
        XCTAssertFalse(signInEntry.exists, "the accounts flow was dismissed on its own")
        assertTreeShowsNothingPresented(in: app)
    }

    func testViewDismissesItsFlow() {
        let app = ExampleApp.launch(signedIn: true)
        app.buttons[Identifiers.product(id: Self.savedID)].tapWhenReady()
        app.buttons[Identifiers.productSave].tapWhenReady()

        let saved = app.descendants(matching: .any)[Identifiers.savedSheet]
        XCTAssertTrue(saved.waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.savedClose].tapWhenReady()
        XCTAssertTrue(saved.waitForNonExistence(timeout: UITestSteps.timeout), "Close left the saved sheet open")
        app.goBack()

        // The wish list's Done closes its flow through the wish list's own router. Shop could only
        // present it because Close left nothing presented: a stack presents one flow at a time.
        openWishlist(in: app)
        app.buttons[Identifiers.wishlistDone].tapWhenReady()
        let wishlist = app.descendants(matching: .any)[Identifiers.wishlist]
        XCTAssertTrue(wishlist.waitForNonExistence(timeout: UITestSteps.timeout), "Done left the wish list open")

        app.openLabTool(.eventLog)
        let savedEntry = app.descendants(matching: .any).matching(Self.savedClose).firstMatch
        XCTAssertTrue(app.reveal(savedEntry), "the event log doesn't show the saved sheet closing")
        let wishlistEntry = app.descendants(matching: .any).matching(Self.wishlistClose).firstMatch
        XCTAssertTrue(app.reveal(wishlistEntry), "the event log doesn't show the wish list closing")
        assertTreeShowsNothingPresented(in: app)
    }

    private func openWishlist(in app: XCUIApplication) {
        app.buttons[Identifiers.shopWishlist].tapWhenReady()
        let wishlist = app.descendants(matching: .any)[Identifiers.wishlist]
        XCTAssertTrue(wishlist.waitForExistence(timeout: UITestSteps.timeout), "the wish list didn't open")
    }

    private func signIn(in app: XCUIApplication) {
        app.textFields[Identifiers.signInEmail].type(Self.email)
        app.secureTextFields[Identifiers.signInPassword].type(Self.password)
        app.buttons[Identifiers.signInButton].tapWhenReady()
        app.closeSavePasswordOffer()
    }

    // From the event log, goes back to the Lab and reads the routers' tree, so the check is on the
    // routers, not only on the screen.
    private func assertTreeShowsNothingPresented(in app: XCUIApplication) {
        app.goBack()
        let row = app.buttons[Identifiers.labTool(.navigationTree)]
        XCTAssertTrue(app.reveal(row), "missing \(Identifiers.labTool(.navigationTree))")
        row.tap()
        let tree = app.staticTexts[Identifiers.navigationTree]
        XCTAssertTrue(tree.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(tree.label.contains(Self.presentedMark), tree.label)
    }
}
