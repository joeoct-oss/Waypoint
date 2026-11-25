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
package nonisolated enum Identifiers {
    package static let splash = "splash"
    package static let signIn = "auth.signIn"
    package static let signInButton = "auth.signIn.submit"
    package static let signInEmail = "auth.signIn.email"
    package static let signInPassword = "auth.signIn.password"
    package static let signInCreateAccount = "auth.signIn.createAccount"
    package static let authCancel = "auth.cancel"
    package static let authError = "auth.error"
    package static let signInReason = "auth.signIn.reason"
    package static let signUpCode = "auth.signUp.code"
    package static let signUpNewCode = "auth.signUp.newCode"
    package static let signUpCodeSent = "auth.signUp.codeSent"
    package static let notice = "notice"
    package static let forgotPassword = "auth.signIn.forgotPassword"
    package static let filterButton = "shop.filter"
    package static let filterApply = "shop.filter.apply"
    package static let shopWishlist = "shop.wishlist"
    package static let resetSend = "auth.reset.send"
    package static let resetSent = "auth.reset.sent"
    package static let resetDone = "auth.reset.done"
    package static let signUpName = "auth.signUp.name"
    package static let signUpEmail = "auth.signUp.email"
    package static let signUpPassword = "auth.signUp.password"
    package static let signUpAcceptTerms = "auth.signUp.acceptTerms"
    package static let signUpTerms = "auth.signUp.terms"
    package static let signUpContinue = "auth.signUp.continue"
    package static let terms = "auth.terms"
    package static let termsDone = "auth.terms.done"
    package static let productSave = "product.save"
    package static let addToCart = "product.addToCart"
    package static let relatedProduct = "product.related"
    package static let navigationIssue = "navigation.issue"
    // Waypoint's own debug screen for a route with no destination in its stack names its title
    // this way.
    package static let missingDestinationTitle = "waypoint.missingDestination.title"
    package static let wishlist = "product.wishlist"
    package static let savedSheet = "product.saved"
    package static let viewWishlist = "product.saved.viewWishlist"
    package static let savedClose = "product.saved.close"
    package static let wishlistDone = "product.wishlist.done"
    package static let signedIn = "auth.signedIn"
    package static let signedInDone = "auth.signedIn.done"
    package static let productReviews = "product.reviews"
    package static let productShare = "product.share"
    package static let searchField = "search.field"
    package static let searchResultCount = "search.resultCount"
    package static let cartEmpty = "cart.empty"
    package static let browseShop = "cart.browseShop"
    package static let checkout = "cart.checkout"
    package static let checkoutAddress = "checkout.address"
    package static let closeCheckout = "checkout.close"
    package static let addAddress = "address.add"
    package static let addressSaved = "address.saved"
    package static let addressLabel = "address.form.label"
    package static let addressStreet = "address.form.street"
    package static let addressCity = "address.form.city"
    package static let addressPostcode = "address.form.postcode"
    package static let addressKeep = "address.form.keep"
    package static let saveAddress = "address.form.save"
    package static let continueToPayment = "checkout.continueToPayment"
    package static let continueToReview = "checkout.continueToReview"
    package static let reviewAddress = "checkout.review.address"
    package static let placeOrder = "checkout.placeOrder"
    package static let orderPlaced = "checkout.orderPlaced"
    package static let continueShopping = "checkout.continueShopping"
    package static let ordersButton = "account.orders"
    package static let addressesButton = "account.addresses"
    package static let accountSignIn = "account.signIn"
    package static let accountName = "account.name"
    package static let accountWishlist = "account.wishlist"
    package static let orderTimeline = "order.timeline"
    package static let signOut = "account.signOut"
    package static let clearData = "settings.clearData"
    package static let confirmClearData = "settings.clearData.confirm"
    package static let duplicatePushRule = "settings.duplicatePushRule"
    package static let tryPushTwice = "settings.tryPushTwice"
    package static let queueLimit = "settings.queueLimit"
    package static let failureCount = "settings.failureCount"
    package static let tryMissingPop = "settings.tryMissingPop"
    package static let tryPresentTwice = "settings.tryPresentTwice"
    package static let tryUnrecovered = "settings.tryUnrecovered"
    package static let mainTabs = "main.tabs"
    package static let productList = "shop.products"
    package static let collectionScreen = "shop.collection"
    package static let goToCart = "shop.goToCart"
    package static let settingsButton = "account.settings"
    package static let labButton = "settings.lab"
    package static let lab = "lab"
    package static let labStylePicker = "lab.style.picker"
    package static let labStyleSample = "lab.style.sample"
    package static let labTryStyle = "lab.style.try"
    package static let labOpenLateDemo = "lab.late.open"
    package static let labLateOutcome = "lab.late.outcome"
    package static let labOpenReviews = "lab.noRouter.openReviews"
    package static let labMissingRouter = "lab.noRouter.issue"
    package static let labPreviewSample = "lab.preview.sample"
    package static let labDemoProduct = "lab.demo.product"
    package static let labDemoAddToCart = "lab.demo.addToCart"
    package static let labDemoReviews = "lab.demo.reviews"
    package static let labDemoReviewsScreen = "lab.demo.reviewsScreen"
    package static let labDemoCart = "lab.demo.cart"
    package static let labDemoClose = "lab.demo.close"
    package static let detailList = "lab.detail.list"
    package static let detailProduct = "lab.detail.product"
    package static let detailAddToCart = "lab.detail.addToCart"
    package static let detailBackToCart = "lab.detail.backToCart"
    package static let detailCart = "lab.detail.cart"
    package static let detailWriteReview = "lab.detail.writeReview"
    package static let detailReviewPosted = "lab.detail.reviewPosted"
    package static let detailReviewRating = "lab.detail.review.rating"
    package static let detailReviewNote = "lab.detail.review.note"
    package static let detailReviewPost = "lab.detail.review.post"
    package static let tabsDemo = "lab.tabs"
    package static let sheetDemoSize = "lab.sheet.size"
    package static let sheetDemoSwipe = "lab.sheet.swipe"
    package static let sheetDemoPresent = "lab.sheet.present"
    package static let sheetDemoCover = "lab.sheet.cover"
    package static let sheetDemoTree = "lab.sheet.tree"
    package static let sheetDemoPresentOnTop = "lab.sheet.presentOnTop"
    package static let sheetDemoDismiss = "lab.sheet.dismiss"
    package static let sheetDemoDismissFlow = "lab.sheet.dismissFlow"
    package static let sheetDemoDismissAll = "lab.sheet.dismissAll"
    package static let tabsDemoSelection = "lab.tabs.selection"
    package static let tabsDemoChange = "lab.tabs.change"
    package static let recoveredToast = "lab.toast.recovered"
    package static let eventLog = "lab.eventLog"
    package static let eventLogFilter = "lab.eventLog.filter"
    package static let navigationTree = "lab.tree"
    package static let copyTree = "lab.tree.copy"

    package static func product(id: Int) -> String {
        "product.\(id)"
    }

    package static func sheetDemoLevel(_ level: Int) -> String {
        "lab.sheet.level.\(level)"
    }

    package static func detailReviewStars(_ rating: Int) -> String {
        "lab.detail.review.stars.\(rating)"
    }

    package static func wishlistSave(id: Int) -> String {
        "product.wishlist.save.\(id)"
    }

    package static func recentSearch(_ term: String) -> String {
        "search.recent.\(term)"
    }

    package static func collection(id: String) -> String {
        "collection.\(id)"
    }

    package static func address(label: String) -> String {
        "address.\(label)"
    }

    package static func order(id: Int) -> String {
        "order.\(id)"
    }

    package static func branch(_ branch: Branch) -> String {
        "root.\(branch.rawValue)"
    }

    package static func entry(_ entry: FlowEntry) -> String {
        "\(entry.branch.rawValue).\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }

    package static func labStory(_ story: ViewModelStory) -> String {
        "lab.story.\(story.rawValue)"
    }

    package static func labTool(_ tool: LabTool) -> String {
        "lab.tool.\(tool.rawValue)"
    }

    package static func eventLogEntry(_ outcome: String) -> String {
        "lab.eventLog.\(outcome)"
    }

    package static func placeholder(_ entry: FlowEntry) -> String {
        "placeholder.\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }
}
