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
    // XCTest's launch returns only once the app settles, which takes a few seconds and, on a Mac
    // under memory load, most of 5 (planning #479). The splash is timed from the app's start, so
    // the launch test holds it up for 10 seconds, long enough to outlast a slow launch.
    private static let splashSeconds = 10
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
    private static let signUpName = "Nova Reader"
    private static let signUpCode = "204816"
    private static let checkoutReason = "Sign in to check out"
    private static let signedInAs = "Signed in as"
    private static let signedOut = "Signed out"
    private static let cartProductID = 1
    private static let cartProductTitle = "Orbit Lamp"
    // How many times the wish list test taps Back before it gives up.
    private static let backTapTries = 3
    // The setPath line: Order placed in the stack, with the steps it replaced gone.
    private static let replacedPath = NSPredicate(
        format: "label CONTAINS 'set' AND label CONTAINS 'Order placed' AND NOT (label CONTAINS 'Review')"
    )
    private static let savedProductID = 2
    private static let savedProductTitle = "Comet Mug"
    private static let savedSearch = "mug"
    private static let savedSearchResultCount = "1 result"
    private static let orderID = 1042
    private static let ordersTitle = "Orders"
    private static let needsAccount = "Needs an account"
    private static let wishlistTitle = "Wish list"
    private static let savedCount = "0 saved"
    private static let newAddressLabel = "Studio"
    private static let newAddressStreet = "9 Nova Lane"
    private static let newAddressCity = "Springfield"
    private static let newAddressPostcode = "40233"

    // A guest's first launch shows the splash, then Shop with every tab, and Account offers Sign
    // in; a signed-in reader's Account shows their name.
    func testLaunchOpensShopForEveryone() {
        let firstLaunch = ExampleApp.launch(splashSeconds: Self.splashSeconds)
        let splash = firstLaunch.descendants(matching: .any)[Identifiers.splash]
        let shop = firstLaunch.navigationBars[Self.shopTitle]
        XCTAssertTrue(splash.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(shop.waitForExistence(timeout: UITestSteps.timeout + TimeInterval(Self.splashSeconds)))
        for title in Self.otherTabTitles {
            XCTAssertTrue(firstLaunch.tabBars.buttons[title].exists, "missing \(title) tab")
        }
        firstLaunch.openTab(Self.accountTitle)
        XCTAssertTrue(firstLaunch.buttons[Identifiers.accountSignIn].waitForExistence(timeout: UITestSteps.timeout))
        firstLaunch.terminate()

        let signedIn = ExampleApp.launch(signedIn: true)
        signedIn.openTab(Self.accountTitle)

        XCTAssertTrue(signedIn.staticTexts[Identifiers.accountName].waitForExistence(timeout: UITestSteps.timeout))
    }

    // AU-02 and AU-03: a guest's Check out opens sign in, which says why; after signing in, a toast
    // names the account and checkout carries on at the address step.
    func testCheckoutAsksToSignIn() {
        let app = ExampleApp.launch()
        addProductToCart(in: app)

        app.buttons[Identifiers.checkout].tapWhenReady()
        let reason = app.staticTexts[Identifiers.signInReason]
        XCTAssertTrue(reason.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(reason.label.hasPrefix(Self.checkoutReason), reason.label)
        signIn(
            password: Self.password,
            in: app
        )

        let notice = app.descendants(matching: .any)[Identifiers.notice]
        XCTAssertTrue(notice.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(notice.label.contains(Self.signedInAs), notice.label)
        // The notice goes after a few seconds, so it's checked before the offer is closed.
        app.closeSavePasswordOffer()
        let addressStep = app.descendants(matching: .any)[Identifiers.checkoutAddress]
        XCTAssertTrue(addressStep.waitForExistence(timeout: UITestSteps.timeout))
    }

    // A guest's Save opens sign in; the three Create account steps keep the typed name on the way
    // back, the terms can't be swiped away, the third step takes the 6-digit code from the email,
    // and the save carries on.
    func testSignUpInSheet() {
        let app = ExampleApp.launch()
        openSavedProduct(in: app)
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
        enterCode(in: app)
        app.buttons[Identifiers.signUpContinue].tapWhenReady()

        let saved = app.descendants(matching: .any)[Identifiers.savedSheet]
        XCTAssertTrue(saved.waitForExistence(timeout: UITestSteps.timeout))
    }

    // MA-01: a recent search fills the field and lists its results under a count, a result opens
    // the product on the Search stack from the search's view model, and Back returns to the
    // results (planning #417). Save shows the small saved sheet, and View wish list swaps it for
    // the wish list.
    func testSearchOpenAndSave() {
        let app = ExampleApp.launch(signedIn: true)

        openSavedProduct(in: app)
        XCTAssertTrue(app.navigationBars[Self.savedProductTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        let result = app.buttons[Identifiers.product(id: Self.savedProductID)]
        XCTAssertTrue(result.waitForExistence(timeout: UITestSteps.timeout), "Back didn't return to the results")
        result.tap()
        app.buttons[Identifiers.productSave].tapWhenReady()
        app.buttons[Identifiers.viewWishlist].tapWhenReady()

        let wishlist = app.descendants(matching: .any)[Identifiers.wishlist]
        XCTAssertTrue(wishlist.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(app.descendants(matching: .any)[Identifiers.savedSheet].exists)
    }

    // MA-02 and the cart's checkout (planning #416): an empty cart says so and Browse the shop
    // opens Shop. With the lamp added, checkout walks address, payment and review, and placing the
    // order replaces the steps with Order placed in one `setPath`, which the event log shows as one
    // line with no Review left. Continue shopping closes checkout and opens Shop at its root, since
    // the tabs share one stack and Add to cart's switch to Cart popped it.
    func testCheckoutPlacesOrder() {
        let app = ExampleApp.launch(signedIn: true)
        app.openTab(Self.cartTitle)
        app.buttons[Identifiers.browseShop].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertFalse(app.buttons[Identifiers.checkout].exists)
        addProductToCart(in: app)

        app.buttons[Identifiers.checkout].tapWhenReady()
        app.buttons[Identifiers.continueToPayment].tapWhenReady()
        app.buttons[Identifiers.continueToReview].tapWhenReady()
        app.buttons[Identifiers.placeOrder].tapWhenReady()
        let placed = app.descendants(matching: .any)[Identifiers.orderPlaced]
        XCTAssertTrue(placed.waitForExistence(timeout: UITestSteps.timeout), "Order placed didn't show")
        app.buttons[Identifiers.continueShopping].tapWhenReady()

        XCTAssertTrue(placed.waitForNonExistence(timeout: UITestSteps.timeout), "checkout stayed open")
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.openLabTool(.eventLog)
        let entry = app.descendants(matching: .any).matching(Self.replacedPath).firstMatch
        XCTAssertTrue(app.reveal(entry), "the event log doesn't show the steps replaced in one change")
    }

    // MA-05: Add a new address pushes a form inside checkout. Saving goes back to the address step
    // with the new address chosen, Review delivers to it, and Account, Addresses lists it too.
    func testCheckoutAddsAddress() {
        let app = ExampleApp.launch(signedIn: true)
        addProductToCart(in: app)
        app.buttons[Identifiers.checkout].tapWhenReady()

        app.buttons[Identifiers.addAddress].tapWhenReady()
        app.textFields[Identifiers.addressLabel].type(Self.newAddressLabel)
        app.textFields[Identifiers.addressStreet].type(Self.newAddressStreet)
        app.textFields[Identifiers.addressCity].type(Self.newAddressCity)
        app.textFields[Identifiers.addressPostcode].type(Self.newAddressPostcode)
        app.buttons[Identifiers.saveAddress].tapWhenReady()

        let toast = app.descendants(matching: .any)[Identifiers.addressSaved]
        XCTAssertTrue(toast.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.buttons[Identifiers.address(label: Self.newAddressLabel)].isSelected)
        app.buttons[Identifiers.continueToPayment].tapWhenReady()
        app.buttons[Identifiers.continueToReview].tapWhenReady()
        let delivery = app.descendants(matching: .any)[Identifiers.reviewAddress]
        XCTAssertTrue(delivery.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(delivery.label.contains(Self.newAddressStreet), "review delivers elsewhere")

        app.goBack()
        app.goBack()
        app.buttons[Identifiers.closeCheckout].tapWhenReady()
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.addressesButton].tapWhenReady()
        let saved = app.descendants(matching: .any)[Identifiers.address(label: Self.newAddressLabel)]
        XCTAssertTrue(saved.waitForExistence(timeout: UITestSteps.timeout))
    }

    // MA-03: a guest's Wish list on Account asks to sign in through the account gate, then the wish
    // list pushes, and back on Account the row shows its count.
    func testAccountWishlistAsksToSignIn() {
        let app = ExampleApp.launch()
        app.openTab(Self.accountTitle)
        let wishlist = app.buttons[Identifiers.accountWishlist]
        XCTAssertTrue(wishlist.waitForExistence(timeout: UITestSteps.timeout), "Account has no Wish list row")
        XCTAssertTrue(wishlist.label.contains(Self.needsAccount), wishlist.label)
        wishlist.tap()

        signIn(
            password: Self.password,
            in: app
        )
        app.closeSavePasswordOffer()
        // The gate pushes the wish list only once the sheet has slid away, so wait for that first.
        let sheet = app.buttons[Identifiers.signInButton]
        XCTAssertTrue(sheet.waitForNonExistence(timeout: UITestSteps.timeout), "the sign-in sheet stayed")
        let wishlistBar = app.navigationBars[Self.wishlistTitle]
        XCTAssertTrue(wishlistBar.waitForExistence(timeout: UITestSteps.timeout), "the wish list didn't push")
        // On a slow run the bar shows before the push ends and a Back tap then is lost, so tap
        // again while the wish list stays.
        let back = wishlistBar.buttons[UITestSteps.backButtonID]
        XCTAssertTrue(back.waitForExistence(timeout: UITestSteps.timeout), "the wish list has no Back button")
        for _ in 0..<Self.backTapTries where wishlistBar.exists {
            app.goBack()
            if wishlistBar.waitForNonExistence(timeout: UITestSteps.settleTime) {
                break
            }
        }

        XCTAssertTrue(wishlistBar.waitForNonExistence(timeout: UITestSteps.timeout), "Back stayed on the wish list")
        XCTAssertTrue(wishlist.waitForExistence(timeout: UITestSteps.timeout), "Account lost its Wish list row")
        XCTAssertTrue(wishlist.label.contains(Self.savedCount), wishlist.label)
    }

    // Orders and an order push on the Account tab's plain stack, which hides the tab bar on them,
    // and Back to the tab's root shows it again.
    func testOrdersPushDetail() {
        let app = ExampleApp.launch(signedIn: true)

        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.ordersButton].tapWhenReady()
        app.buttons[Identifiers.order(id: Self.orderID)].tapWhenReady()

        XCTAssertTrue(app.navigationBars["Order \(Self.orderID)"].waitForExistence(timeout: UITestSteps.timeout))
        let timeline = app.descendants(matching: .any)[Identifiers.orderTimeline]
        XCTAssertTrue(timeline.exists, "the order shows no timeline")
        XCTAssertTrue(app.waitForTabBar(shown: false), "a pushed account screen showed the tab bar")
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.ordersTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()

        XCTAssertTrue(app.navigationBars[Self.accountTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.waitForTabBar(shown: true), "the account tab hid the tab bar")
    }

    // AU-05: Sign out, in Settings, goes back to Account as a guest: the sign-in prompt, Orders
    // saying it needs an account, and the tabs still there.
    func testSignOutStaysAsGuest() {
        let app = ExampleApp.launch(signedIn: true)
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.settingsButton].tapWhenReady()

        let signOut = app.buttons[Identifiers.signOut]
        XCTAssertTrue(app.reveal(signOut))
        signOut.tap()

        // The notice first: it shows for 3 s, and on a loaded Mac the way back to Account can take
        // longer than that, so it would be gone by the time the test looked for it.
        let notice = app.descendants(matching: .any)[Identifiers.notice]
        XCTAssertTrue(notice.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(notice.label.contains(Self.signedOut), notice.label)
        XCTAssertTrue(app.buttons[Identifiers.accountSignIn].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.navigationBars[Self.accountTitle].exists)
        let orders = app.buttons[Identifiers.ordersButton]
        XCTAssertTrue(orders.label.contains(Self.needsAccount), orders.label)
        XCTAssertTrue(app.tabBars.buttons[Self.shopTitle].exists)
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

    // TX-02: with the lamp in the cart, Shop's Go to cart lands on the cart in one transaction,
    // with the lamp under it, so Back goes to the lamp, then to Shop.
    func testGoToCartIsOneTransaction() {
        let app = ExampleApp.launch(signedIn: true)
        addProductToCart(in: app)
        // Add to cart's switch to Cart popped the one stack the tabs share, so Shop opens at its
        // root.
        app.openTab(Self.shopTitle)
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))

        app.buttons[Identifiers.goToCart].tapWhenReady()
        XCTAssertTrue(app.navigationBars[Self.cartTitle].waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(app.buttons[Identifiers.checkout].exists)

        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.cartProductTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(app.navigationBars[Self.shopTitle].waitForExistence(timeout: UITestSteps.timeout))
    }

    // Opens Search, taps the recent search for the mug, waits for its one result, then opens it.
    private func openSavedProduct(in app: XCUIApplication) {
        app.openTab(Self.searchTitle)
        app.buttons[Identifiers.recentSearch(Self.savedSearch)].tapWhenReady()
        let count = app.staticTexts[Identifiers.searchResultCount]
        XCTAssertTrue(count.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertEqual(count.label, Self.savedSearchResultCount)
        app.buttons[Identifiers.product(id: Self.savedProductID)].tapWhenReady()
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
        // The terms sheet is locked (planning #412): a swipe leaves it, and only Done closes it.
        terms.swipeDown(velocity: .fast)
        XCTAssertFalse(terms.waitForNonExistence(timeout: UITestSteps.stayTime), "a swipe closed the terms")
        app.buttons[Identifiers.termsDone].tapWhenReady()
        XCTAssertTrue(terms.waitForNonExistence(timeout: UITestSteps.timeout), "Done didn't close the terms")
        app.switches[Identifiers.signUpAcceptTerms].turnOn()
    }

    // Sends a new code first, so the step's Send a new code is covered too.
    private func enterCode(in app: XCUIApplication) {
        app.buttons[Identifiers.signUpNewCode].tapWhenReady()
        let sent = app.staticTexts[Identifiers.signUpCodeSent]
        XCTAssertTrue(sent.waitForExistence(timeout: UITestSteps.timeout))
        app.textFields[Identifiers.signUpCode].type(Self.signUpCode)
    }
}
