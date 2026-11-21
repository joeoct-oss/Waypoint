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
    static let signInReason = "auth.signIn.reason"
    static let signUpCode = "auth.signUp.code"
    static let signUpNewCode = "auth.signUp.newCode"
    static let signUpCodeSent = "auth.signUp.codeSent"
    static let notice = "notice"
    static let forgotPassword = "auth.signIn.forgotPassword"
    static let filterButton = "shop.filter"
    static let filterApply = "shop.filter.apply"
    static let shopWishlist = "shop.wishlist"
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
    static let savedSheet = "product.saved"
    static let viewWishlist = "product.saved.viewWishlist"
    static let savedClose = "product.saved.close"
    static let wishlistDone = "product.wishlist.done"
    static let signedIn = "auth.signedIn"
    static let signedInDone = "auth.signedIn.done"
    static let productReviews = "product.reviews"
    static let productShare = "product.share"
    static let searchResultCount = "search.resultCount"
    static let cartEmpty = "cart.empty"
    static let browseShop = "cart.browseShop"
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
    static let accountWishlist = "account.wishlist"
    static let orderTimeline = "order.timeline"
    static let signOut = "account.signOut"
    static let clearData = "settings.clearData"
    static let confirmClearData = "settings.clearData.confirm"
    static let duplicatePushRule = "settings.duplicatePushRule"
    static let queueLimit = "settings.queueLimit"
    static let failureCount = "settings.failureCount"
    static let tryMissingPop = "settings.tryMissingPop"
    static let tryPresentTwice = "settings.tryPresentTwice"
    static let mainTabs = "main.tabs"
    static let productList = "shop.products"
    static let collectionScreen = "shop.collection"
    static let goToCart = "shop.goToCart"
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
    static let detailList = "lab.detail.list"
    static let detailProduct = "lab.detail.product"
    static let detailAddToCart = "lab.detail.addToCart"
    static let detailBackToCart = "lab.detail.backToCart"
    static let detailCart = "lab.detail.cart"
    static let tabsDemo = "lab.tabs"
    static let sheetDemoSize = "lab.sheet.size"
    static let sheetDemoSwipe = "lab.sheet.swipe"
    static let sheetDemoPresent = "lab.sheet.present"
    static let sheetDemoCover = "lab.sheet.cover"
    static let sheetDemoTree = "lab.sheet.tree"
    static let sheetDemoPresentOnTop = "lab.sheet.presentOnTop"
    static let sheetDemoDismiss = "lab.sheet.dismiss"
    static let sheetDemoDismissFlow = "lab.sheet.dismissFlow"
    static let sheetDemoDismissAll = "lab.sheet.dismissAll"
    static let tabsDemoSelection = "lab.tabs.selection"
    static let tabsDemoChange = "lab.tabs.change"
    static let recoveredToast = "lab.toast.recovered"
    static let eventLog = "lab.eventLog"
    static let eventLogFilter = "lab.eventLog.filter"
    static let navigationTree = "lab.tree"
    static let copyTree = "lab.tree.copy"

    static func product(id: Int) -> String {
        "product.\(id)"
    }

    static func sheetDemoLevel(_ level: Int) -> String {
        "lab.sheet.level.\(level)"
    }

    static func wishlistSave(id: Int) -> String {
        "product.wishlist.save.\(id)"
    }

    static func recentSearch(_ term: String) -> String {
        "search.recent.\(term)"
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

    static func labTool(_ tool: LabTool) -> String {
        "lab.tool.\(tool.rawValue)"
    }

    static func eventLogEntry(_ outcome: String) -> String {
        "lab.eventLog.\(outcome)"
    }

    static func placeholder(_ entry: FlowEntry) -> String {
        "placeholder.\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }
}
