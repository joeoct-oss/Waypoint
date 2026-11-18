//
//  JourneyTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The shop's user journeys, one test for each story on the design canvas. Every launch starts from
// a fresh install. Guests use the same tabs as signed-in readers, and an action that needs an
// account (Check out, Save, Orders) asks for one in a sheet, then carries on.
@MainActor
final class JourneyTests: XCTestCase {
    // XCTest takes a few seconds to launch the app and wait for it to settle, longer than the usual
    // splash, so the launch test holds the splash up for 5 seconds.
    private static let splashSeconds = 5
    private static let shopTitle = "Shop"
    private static let searchTitle = "Search"
    private static let cartTitle = "Cart"
    private static let accountTitle = "Account"
    private static let otherTabTitles = [
        searchTitle,
        cartTitle,
        accountTitle,
    ]
    private static let email = "nova@example.com"
    private static let password = "orbit-2026"
    private static let wrongPassword = "wrong"
    private static let signUpName = "Nova Reader"
    private static let cartProductID = 1
    private static let cartProductTitle = "Orbit Lamp"
    private static let savedProductID = 2
    private static let orderID = 1042

    func testLaunchOpensShopForEveryone() {
        let firstLaunch = ExampleApp.launch(splashSeconds: Self.splashSeconds)
        let splash = firstLaunch.descendants(matching: .any)[Identifiers.splash]
        let shop = firstLaunch.navigationBars[Self.shopTitle]
        XCTAssertTrue(splash.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(shop.waitForExistence(timeout: UITestSteps.timeout + TimeInterval(Self.splashSeconds)))
        firstLaunch.terminate()

        let signedIn = ExampleApp.launch(signedIn: true)
        signedIn.openTab(Self.accountTitle)

        XCTAssertTrue(signedIn.staticTexts[Identifiers.accountName].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testGuestSeesAllTabs() {
        let app = ExampleApp.launch()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        for title in Self.otherTabTitles {
            XCTAssertTrue(app.tabBars.buttons[title].exists, "missing \(title) tab")
        }
        app.openTab(Self.accountTitle)
        XCTAssertTrue(app.buttons[Identifiers.accountSignIn].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testCheckoutAsksGuestToSignIn() {
        let app = ExampleApp.launch()
        addProductToCart(in: app)

        app.buttons[Identifiers.checkout].tapWhenReady()
        signIn(
            password: Self.password,
            in: app
        )

        XCTAssertTrue(app.buttons[Identifiers.placeOrder].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testWrongPasswordShowsError() {
        let app = ExampleApp.launch()
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.accountSignIn].tapWhenReady()

        signIn(
            password: Self.wrongPassword,
            in: app
        )
        let error = app.descendants(matching: .any)[Identifiers.authError]
        XCTAssertTrue(error.waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.authCancel].tapWhenReady()

        XCTAssertTrue(app.buttons[Identifiers.accountSignIn].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testSaveAsksGuestToCreateAccount() {
        let app = ExampleApp.launch()
        app.openTab(Self.searchTitle)
        app.buttons[Identifiers.product(id: Self.savedProductID)].tapWhenReady()
        app.buttons[Identifiers.productSave].tapWhenReady()
        app.buttons[Identifiers.signInCreateAccount].tapWhenReady()

        fillDetails(in: app)
        app.buttons[Identifiers.signUpContinue].tapWhenReady()
        app.goBack()
        let name = app.textFields[Identifiers.signUpName]
        XCTAssertTrue(name.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertEqual(name.value as? String, Self.signUpName, "going back lost the typed name")
        app.buttons[Identifiers.signUpContinue].tapWhenReady()
        choosePassword(in: app)
        app.buttons[Identifiers.signUpContinue].tapWhenReady()
        app.buttons[Identifiers.signUpContinue].tapWhenReady()

        let wishlist = app.descendants(matching: .any)[Identifiers.wishlist]
        XCTAssertTrue(wishlist.waitForExistence(timeout: UITestSteps.timeout))
    }

    func testResetPasswordSheet() {
        let app = ExampleApp.launch()
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.accountSignIn].tapWhenReady()

        app.buttons[Identifiers.forgotPassword].tapWhenReady()
        app.buttons[Identifiers.resetSend].tapWhenReady()
        let sent = app.descendants(matching: .any)[Identifiers.resetSent]
        XCTAssertTrue(sent.waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.resetDone].tapWhenReady()

        XCTAssertTrue(app.buttons[Identifiers.signInButton].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(sent.exists)
    }

    func testSearchOpenAndSave() {
        let app = ExampleApp.launch(signedIn: true)

        app.openTab(Self.searchTitle)
        app.buttons[Identifiers.product(id: Self.savedProductID)].tapWhenReady()
        app.buttons[Identifiers.productSave].tapWhenReady()

        let wishlist = app.descendants(matching: .any)[Identifiers.wishlist]
        XCTAssertTrue(wishlist.waitForExistence(timeout: UITestSteps.timeout))
    }

    func testCheckoutFromCartTab() {
        let app = ExampleApp.launch(signedIn: true)
        addProductToCart(in: app)

        app.buttons[Identifiers.checkout].tapWhenReady()
        app.buttons[Identifiers.placeOrder].tapWhenReady()
        let placed = app.descendants(matching: .any)[Identifiers.orderPlaced]
        XCTAssertTrue(placed.waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.continueShopping].tapWhenReady()

        // Shop keeps its place, so it still shows the product the order started from, with the tab
        // bar hidden as on every pushed screen.
        XCTAssertTrue(app.navigationBars[Self.cartProductTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(placed.exists)
    }

    func testOrdersPushDetail() {
        let app = ExampleApp.launch(signedIn: true)

        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.ordersButton].tapWhenReady()
        app.buttons[Identifiers.order(id: Self.orderID)].tapWhenReady()

        XCTAssertTrue(app.navigationBars["Order \(Self.orderID)"].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testSignOutKeepsTheApp() {
        let app = ExampleApp.launch(signedIn: true)
        app.openTab(Self.accountTitle)

        app.buttons[Identifiers.signOut].tapWhenReady()

        XCTAssertTrue(app.buttons[Identifiers.accountSignIn].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.tabBars.buttons[Self.shopTitle].exists)
    }

    func testSettingsOpensLab() {
        let app = ExampleApp.launch()

        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.settingsButton].tapWhenReady()
        app.buttons[Identifiers.labButton].tapWhenReady()

        XCTAssertTrue(app.buttons[Identifiers.branch(.swiftUI)].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testClearAllDataStartsOver() {
        let app = ExampleApp.launch(signedIn: true)
        addProductToCart(in: app)

        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.settingsButton].tapWhenReady()
        app.buttons[Identifiers.clearData].tapWhenReady()
        // On iOS 27 the confirmation is a popover whose button holds a second button with the same
        // identifier, so the test taps the first.
        app.buttons[Identifiers.confirmClearData].firstMatch.tapWhenReady()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.openTab(Self.cartTitle)
        XCTAssertFalse(app.buttons[Identifiers.product(id: Self.cartProductID)].exists, "the cart kept a product")
        app.openTab(Self.accountTitle)
        XCTAssertTrue(app.buttons[Identifiers.accountSignIn].waitForExistence(timeout: UITestSteps.timeout))
    }

    private func addProductToCart(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.product(id: Self.cartProductID)].tapWhenReady()
        app.buttons[Identifiers.addToCart].tapWhenReady()
        XCTAssertTrue(app.buttons[Identifiers.checkout].waitForExistence(timeout: UITestSteps.timeout))
    }

    private func signIn(
        password: String,
        in app: XCUIApplication
    ) {
        app.textFields[Identifiers.signInEmail].type(Self.email)
        app.secureTextFields[Identifiers.signInPassword].type(password)
        app.buttons[Identifiers.signInButton].tapWhenReady()
    }

    private func fillDetails(in app: XCUIApplication) {
        app.textFields[Identifiers.signUpName].type(Self.signUpName)
        app.textFields[Identifiers.signUpEmail].type(Self.email)
    }

    private func choosePassword(in app: XCUIApplication) {
        app.secureTextFields[Identifiers.signUpPassword].type(Self.password)
        app.buttons[Identifiers.signUpTerms].tapWhenReady()
        let terms = app.descendants(matching: .any)[Identifiers.terms]
        XCTAssertTrue(terms.waitForExistence(timeout: UITestSteps.timeout))
        terms.buttons.firstMatch.tap()
        app.switches[Identifiers.signUpAcceptTerms].turnOn()
    }
}
