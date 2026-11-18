//
//  JourneyTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The shop's user journeys, one test for each story on the design canvas: launch by session, sign
// in, sign up, reset password, the guest's tabs, search and save, checkout from Cart, an order's
// detail and the Lab under Settings.
@MainActor
final class JourneyTests: XCTestCase {
    // XCTest takes a few seconds to launch the app and wait for it to settle, longer than the usual
    // splash, so the launch test holds the splash up for 5 seconds.
    private static let splashSeconds = 5
    private static let shopTitle = "Shop"
    private static let searchTitle = "Search"
    private static let cartTitle = "Cart"
    private static let accountTitle = "Account"
    private static let signUpName = "Nova Reader"
    private static let signUpEmail = "nova@example.com"
    private static let signUpPassword = "orbit-2026"
    private static let savedProductID = 2
    private static let orderID = 1042

    func testLaunchRoutesBySession() {
        let firstLaunch = ExampleApp.launch(splashSeconds: Self.splashSeconds)
        let splash = firstLaunch.descendants(matching: .any)[Identifiers.splash]
        let welcome = firstLaunch.buttons[Identifiers.welcomeSignIn]
        XCTAssertTrue(splash.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(welcome.waitForExistence(timeout: UITestSteps.timeout + TimeInterval(Self.splashSeconds)))
        firstLaunch.terminate()

        let signedIn = ExampleApp.launch(signedIn: true)

        XCTAssertTrue(signedIn.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(signedIn.buttons[Identifiers.welcomeSignIn].exists)
    }

    func testSignInLandsOnShop() {
        let app = ExampleApp.launch()

        app.buttons[Identifiers.welcomeSignIn].tapWhenReady()
        app.buttons[Identifiers.signInButton].tapWhenReady()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.tabBars.buttons[Self.accountTitle].exists)
    }

    func testSignUpSwitchesToShop() {
        let app = ExampleApp.launch()
        app.buttons[Identifiers.welcomeCreateAccount].tapWhenReady()

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

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.tabBars.buttons[Self.accountTitle].exists)
    }

    func testResetPasswordSheet() {
        let app = ExampleApp.launch()
        app.buttons[Identifiers.welcomeSignIn].tapWhenReady()

        app.buttons[Identifiers.forgotPassword].tapWhenReady()
        app.buttons[Identifiers.resetSend].tapWhenReady()
        let sent = app.descendants(matching: .any)[Identifiers.resetSent]
        XCTAssertTrue(sent.waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.resetDone].tapWhenReady()

        XCTAssertTrue(app.buttons[Identifiers.signInButton].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(sent.exists)
    }

    func testGuestSeesTwoTabs() {
        let app = ExampleApp.launch()

        app.buttons[Identifiers.welcomeGuest].tapWhenReady()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.tabBars.buttons[Self.searchTitle].exists)
        XCTAssertFalse(app.tabBars.buttons[Self.cartTitle].exists)
        XCTAssertFalse(app.tabBars.buttons[Self.accountTitle].exists)
        XCTAssertTrue(app.buttons[Identifiers.guestSignIn].exists)
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

        app.openTab(Self.cartTitle)
        app.buttons[Identifiers.checkout].tapWhenReady()
        app.buttons[Identifiers.placeOrder].tapWhenReady()
        let placed = app.descendants(matching: .any)[Identifiers.orderPlaced]
        XCTAssertTrue(placed.waitForExistence(timeout: UITestSteps.timeout))
        app.buttons[Identifiers.continueShopping].tapWhenReady()

        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(placed.exists)
    }

    func testOrdersPushDetail() {
        let app = ExampleApp.launch(signedIn: true)

        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.ordersButton].tapWhenReady()
        app.buttons[Identifiers.order(id: Self.orderID)].tapWhenReady()

        XCTAssertTrue(app.navigationBars["Order \(Self.orderID)"].waitForExistence(timeout: UITestSteps.timeout))
    }

    func testSettingsOpensLab() {
        let app = ExampleApp.launch(signedIn: true)

        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.settingsButton].tapWhenReady()
        app.buttons[Identifiers.labButton].tapWhenReady()

        XCTAssertTrue(app.buttons[Identifiers.branch(.swiftUI)].waitForExistence(timeout: UITestSteps.timeout))
    }

    private func fillDetails(in app: XCUIApplication) {
        app.textFields[Identifiers.signUpName].type(Self.signUpName)
        app.textFields[Identifiers.signUpEmail].type(Self.signUpEmail)
    }

    private func choosePassword(in app: XCUIApplication) {
        app.secureTextFields[Identifiers.signUpPassword].type(Self.signUpPassword)
        app.buttons[Identifiers.signUpTerms].tapWhenReady()
        let terms = app.descendants(matching: .any)[Identifiers.terms]
        XCTAssertTrue(terms.waitForExistence(timeout: UITestSteps.timeout))
        terms.buttons.firstMatch.tap()
        app.switches[Identifiers.signUpAcceptTerms].turnOn()
    }
}
