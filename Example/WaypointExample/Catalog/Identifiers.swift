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
    static let signIn = "auth.signIn"
    static let signInButton = "auth.signIn.submit"
    static let signInEmail = "auth.signIn.email"
    static let signInPassword = "auth.signIn.password"
    static let signInCreateAccount = "auth.signIn.createAccount"
    static let authCancel = "auth.cancel"
    static let authError = "auth.error"
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
    static let termsDone = "auth.terms.done"
    static let productSave = "product.save"
    static let addToCart = "product.addToCart"
    static let relatedProduct = "product.related"
    static let navigationIssue = "navigation.issue"
    // Waypoint's own debug screen for a route with no destination in its stack names its title
    // this way.
    static let missingDestinationTitle = "waypoint.missingDestination.title"
    static let wishlist = "product.wishlist"
    static let checkout = "cart.checkout"
    static let checkoutAddress = "checkout.address"
    static let closeCheckout = "checkout.close"
    static let addAddress = "address.add"
    static let addressSaved = "address.saved"
    static let addressLabel = "address.form.label"
    static let addressStreet = "address.form.street"
    static let addressCity = "address.form.city"
    static let addressPostcode = "address.form.postcode"
    static let addressKeep = "address.form.keep"
    static let saveAddress = "address.form.save"
    static let continueToPayment = "checkout.continueToPayment"
    static let continueToReview = "checkout.continueToReview"
    static let reviewAddress = "checkout.review.address"
    static let placeOrder = "checkout.placeOrder"
    static let orderPlaced = "checkout.orderPlaced"
    static let continueShopping = "checkout.continueShopping"
    static let ordersButton = "account.orders"
    static let addressesButton = "account.addresses"
    static let accountSignIn = "account.signIn"
    static let accountName = "account.name"
    static let signOut = "account.signOut"
    static let clearData = "settings.clearData"
    static let confirmClearData = "settings.clearData.confirm"
    static let mainTabs = "main.tabs"
    static let productList = "shop.products"
    static let collectionScreen = "shop.collection"
    static let settingsButton = "account.settings"
    static let labButton = "settings.lab"
    static let lab = "lab"
    static let labStylePicker = "lab.style.picker"
    static let labStyleSample = "lab.style.sample"
    static let labTryStyle = "lab.style.try"
    static let labOpenLateDemo = "lab.late.open"
    static let labLateOutcome = "lab.late.outcome"
    static let labOpenReviews = "lab.noRouter.openReviews"
    static let labMissingRouter = "lab.noRouter.issue"
    static let labPreviewSample = "lab.preview.sample"
    static let labDemoProduct = "lab.demo.product"
    static let labDemoAddToCart = "lab.demo.addToCart"
    static let labDemoReviews = "lab.demo.reviews"
    static let labDemoReviewsScreen = "lab.demo.reviewsScreen"
    static let labDemoCart = "lab.demo.cart"
    static let labDemoClose = "lab.demo.close"

    static func product(id: Int) -> String {
        "product.\(id)"
    }

    static func collection(id: String) -> String {
        "collection.\(id)"
    }

    static func address(label: String) -> String {
        "address.\(label)"
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

    static func labStory(_ story: ViewModelStory) -> String {
        "lab.story.\(story.rawValue)"
    }

    static func placeholder(_ entry: FlowEntry) -> String {
        "placeholder.\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }
}
