//
//  Identifiers.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Accessibility identifiers shared by the app and its UI tests. Journey screens use
// `<flow>.<screen>`, and the Navigation Lab uses `root.<branch>`, `<branch>.<flow>.<kind>` for an
// entry, and `placeholder.<flow>.<kind>` for the screen it opens.
enum Identifiers {
    static let splash = "splash"
    static let welcomeSignIn = "auth.welcome.signIn"
    static let welcomeCreateAccount = "auth.welcome.createAccount"
    static let welcomeGuest = "auth.welcome.guest"
    static let signIn = "auth.signIn"
    static let signInButton = "auth.signIn.submit"
    static let forgotPassword = "auth.signIn.forgotPassword"
    static let resetSend = "auth.reset.send"
    static let resetSent = "auth.reset.sent"
    static let resetDone = "auth.reset.done"
    static let signUpName = "auth.signUp.name"
    static let signUpEmail = "auth.signUp.email"
    static let signUpPassword = "auth.signUp.password"
    static let signUpAcceptTerms = "auth.signUp.acceptTerms"
    static let signUpTerms = "auth.signUp.terms"
    static let signUpContinue = "auth.signUp.continue"
    static let terms = "auth.terms"
    static let guestSignIn = "shop.signIn"
    static let productSave = "product.save"
    static let addToCart = "product.addToCart"
    static let wishlist = "product.wishlist"
    static let checkout = "cart.checkout"
    static let placeOrder = "checkout.placeOrder"
    static let orderPlaced = "checkout.orderPlaced"
    static let continueShopping = "checkout.continueShopping"
    static let ordersButton = "account.orders"
    static let mainTabs = "main.tabs"
    static let productList = "shop.products"
    static let settingsButton = "account.settings"
    static let labButton = "settings.lab"
    static let lab = "lab"

    static func product(id: Int) -> String {
        "product.\(id)"
    }

    static func order(id: Int) -> String {
        "order.\(id)"
    }

    static func branch(_ branch: Branch) -> String {
        "root.\(branch.rawValue)"
    }

    static func entry(_ entry: FlowEntry) -> String {
        "\(entry.branch.rawValue).\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }

    static func placeholder(_ entry: FlowEntry) -> String {
        "placeholder.\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }
}
