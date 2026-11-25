//
//  AccountCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// The account tab, which `AccountFactory` builds with its screens: the profile at the root (or
// Sign in for a guest), orders, the wish list, addresses and settings pushed above it, and the
// Navigation Lab under settings with the twenty demo entries and its tools: the whole tree and the
// event log. Orders, the wish list and Addresses need an account, so the account gate asks a guest
// to sign in first. Add a new address pushes the form; saving keeps the address in the address
// book, which checkout shares, and goes back to the list. Sign out, in Settings, ends the session
// and goes back to Account, which then shows the guest prompt; the reader stays in the app.
// Settings also shows the app's navigation rules, and tries the two calls their fallbacks recover:
// going back to a screen that isn't in the stack, and opening sign in while it is up, and one no
// fallback covers, closing the tab's stack, which `onNavigationFailure` counts. Clear all data
// reports to the app coordinator, which clears the store and starts the window over.
//
// The stack runs on Waypoint: `router`, which Waypoint makes and the main tabs make the one stack
// every tab shares, is drawn by `MainTabView` with `WaypointStack` around the tabs. `root` draws
// the tab's root, and each screen above it is an `AccountRoute`, so the journey lines follow the
// reader through Account too.
//
// Conformances:
// - `StackCoordinator`, so Waypoint makes its router and the main tabs make it the shared stack.
// - `Observable` (from `@Observable`), so the account's root redraws when the account changes.
@Observable
final class AccountCoordinator: StackCoordinator {
    // How long Open Orders twice waits before its second push: long enough for the stack to start
    // the first push, well inside its animation.
    private static let secondPushDelay = Duration.milliseconds(150)

    private let launch: LaunchOptions
    private let addressBook: AddressBook
    private let gate: AccountGate
    private let factory: AccountFactory
    private let onClearAllData: () -> Void
    private let rules: NavigationRules
    private let issues: IssueLog
    // Runs the Lab's view and view-model demos, each full screen on a Waypoint stack of its own.
    let labDemos: LabDemoCoordinator

    // The tab's root: the profile, or Sign in for a guest.
    var root: some View {
        makeAccountFlow()
    }

    init(
        launch: LaunchOptions,
        dependencies: AccountDependencies,
        factory: AccountFactory,
        onClearAllData: @escaping () -> Void
    ) {
        addressBook = dependencies.addresses
        gate = dependencies.gate
        self.factory = factory
        self.onClearAllData = onClearAllData
        rules = dependencies.rules
        issues = dependencies.issues
        self.launch = launch
        labDemos = factory.makeLabDemos(reviewsDelay: launch.labReviewsDelay)
    }

    // Registers the account's screens before the stack is drawn, since the registry is strict and
    // a launch into the Lab pushes them first.
    func registerDestinations(on router: StackRouter) {
        router.register(AccountRoute.self)
    }

    // A launch that opens the Lab starts on it, or on one of its branches or entries. The main tabs
    // call it once their shared stack is made, so the path lands on that stack.
    func openLaunchPath() {
        let path = Self.makePath(for: launch)
        guard !path.isEmpty else {
            return
        }
        router.setPath {
            for route in path {
                route
            }
        }
        if let demo = launch.entry?.demo {
            showLabDemo(demo)
        }
    }

    private static func makePath(for launch: LaunchOptions) -> [AccountRoute] {
        guard launch.opensLab else {
            return []
        }
        let lab: [AccountRoute] = [.settings, .lab]
        guard let branch = launch.branch else {
            return lab
        }
        guard let entry = launch.entry, !entry.isRunnable else {
            return lab + [.labBranch(branch)]
        }
        return lab + [.labBranch(branch), .labFlow(entry)]
    }

    func makeAccountFlow() -> some View {
        factory.makeAccount(
            onSignIn: { self.showSignIn() },
            onShowOrders: { self.openOrders() },
            onShowWishlist: { self.openWishlist() },
            onShowAddresses: { self.openAddresses() },
            onShowSettings: { self.showSettings() }
        )
        .screenChrome(
            title: MainTab.account.title,
            kind: nil,
            router: router,
            route: nil
        )
    }

    func makeDestination(for screen: AccountRoute) -> some View {
        makeScreen(for: screen)
            .screenChrome(
                title: screen.title,
                kind: screen.kind,
                router: router,
                route: AnyRoute(screen)
            )
    }

    func showSignIn() {
        gate.showSignIn()
    }

    func openOrders() {
        gate.requireAccount(for: .orders) { self.showOrders() }
    }

    func showOrders() {
        router.push(AccountRoute.orders)
    }

    func showOrder(_ order: Order) {
        router.push(AccountRoute.order(order))
    }

    func openWishlist() {
        gate.requireAccount(for: .wishlist) { self.showWishlist() }
    }

    func showWishlist() {
        router.push(AccountRoute.wishlist)
    }

    func openAddresses() {
        gate.requireAccount(for: .addresses) { self.showAddresses() }
    }

    func showAddresses() {
        router.push(AccountRoute.addresses)
    }

    func showAddAddress() {
        router.push(AccountRoute.addAddress)
    }

    // Keeps the form's address in the address book and goes back to the list.
    func addAddress(_ address: Address) {
        addressBook.add(address)
        router.pop()
    }

    func showSettings() {
        router.push(AccountRoute.settings)
    }

    func showLab() {
        router.push(AccountRoute.lab)
    }

    func showLabBranch(_ branch: Branch) {
        router.push(AccountRoute.labBranch(branch))
    }

    // An entry that runs for real opens full screen on a stack of its own, because stacks don't
    // nest. The others push their placeholder.
    func showLabFlow(_ entry: FlowEntry) {
        if let demo = entry.demo {
            showLabDemo(demo)
            return
        }
        router.push(AccountRoute.labFlow(entry))
    }

    // A wrapper with no router above it can't be shown on the account stack, which is a Waypoint
    // stack, so that story opens full screen in a plain SwiftUI stack instead of being pushed.
    func showLabStory(_ story: ViewModelStory) {
        guard story != .noRouter else {
            showLabDemo(.noRouter)
            return
        }
        router.push(AccountRoute.labStory(story))
    }

    func showLabTool(_ tool: LabTool) {
        router.push(AccountRoute.labTool(tool))
    }

    func showLabDemo(_ demo: LabDemo) {
        labDemos.showDemo(demo)
    }

    // Ends the session and goes back to Account, which then shows the guest prompt.
    func signOut() {
        gate.signOut()
        router.popToRoot()
    }

    // Settings' "Open Orders twice": pushes Orders, then again while the first push still animates,
    // as a fast double tap would if iOS let both taps through. The duplicate push rule decides:
    // `.skipWhileInFlight` skips the second, `.allow` pushes Orders twice.
    func showPushTwice() {
        router.push(AccountRoute.orders)
        Task { [router] in
            try? await Task.sleep(for: Self.secondPushDelay)
            router.push(AccountRoute.orders)
        }
    }

    // Settings' "Go back to Orders": Orders isn't in the stack, so the call fails and the app's
    // fallback pops to Account instead, which the issue banner and the event log show.
    func showMissingPop() {
        router.popTo(AccountRoute.orders)
    }

    // Settings' "Open sign in twice": the second present fails because sign in is already up, and
    // the app's fallback replaces the first sheet with the second in one change.
    func showPresentTwice() {
        gate.showSignIn()
        gate.showSignIn()
    }

    // Settings' "Close the Account tab": the tab's stack wasn't presented, so `dismissFlow` has
    // nothing to dismiss. No fallback covers it, so the configuration's `onNavigationFailure`
    // counts it.
    func showUnrecovered() {
        router.dismissFlow()
    }

    func clearAllData() {
        onClearAllData()
    }

    @ViewBuilder
    private func makeScreen(for screen: AccountRoute) -> some View {
        switch screen {
        case .orders:
            makeOrdersFlow()
        case .order(let order):
            makeOrderFlow(order)
        case .wishlist:
            makeWishlistFlow()
        case .addresses:
            makeAddressesFlow()
        case .addAddress:
            makeAddAddressFlow()
        case .settings:
            makeSettingsFlow()
        case .lab:
            makeLabFlow()
        case .labBranch(let branch):
            makeLabBranchFlow(branch)
        case .labFlow(let entry):
            makeLabPlaceholderFlow(entry)
        case .labStory(let story):
            makeLabStoryFlow(story)
        case .labTool(let tool):
            makeLabToolFlow(tool)
        }
    }

    private func makeOrdersFlow() -> some View {
        factory.makeOrders(onSelect: { self.showOrder($0) })
    }

    private func makeOrderFlow(_ order: Order) -> some View {
        factory.makeOrder(order)
    }

    private func makeWishlistFlow() -> some View {
        factory.makeWishlist()
    }

    private func makeAddressesFlow() -> some View {
        factory.makeAddresses(onAddAddress: { self.showAddAddress() })
    }

    private func makeAddAddressFlow() -> some View {
        factory.makeAddAddress(onSave: { self.addAddress($0) })
    }

    private func makeSettingsFlow() -> some View {
        factory.makeSettings(
            onShowLab: { self.showLab() },
            onClearAllData: { self.clearAllData() },
            onSignOut: { self.signOut() },
            rules: SettingsRules(
                pushesTwice: rules.duplicatePushRule == .allow,
                queueLimit: rules.queueLimit,
                failureCount: issues.failureCount,
                onSetPushesTwice: { self.rules.setPushesTwice($0) },
                onTryPushTwice: { self.showPushTwice() },
                onTryMissingPop: { self.showMissingPop() },
                onTryPresentTwice: { self.showPresentTwice() },
                onTryUnrecovered: { self.showUnrecovered() }
            )
        )
    }

    private func makeLabFlow() -> some View {
        factory.makeLab(
            onSelectBranch: { self.showLabBranch($0) },
            onSelectStory: { self.showLabStory($0) },
            onSelectTool: { self.showLabTool($0) }
        )
    }

    @ViewBuilder
    private func makeLabBranchFlow(_ branch: Branch) -> some View {
        switch branch {
        case .swiftUI:
            makeSwiftUIBranchFlow()
        case .uiKit:
            makeUIKitBranchFlow()
        }
    }

    private func makeSwiftUIBranchFlow() -> some View {
        SwiftUIBranchView(onSelect: { self.showLabFlow($0) })
    }

    private func makeUIKitBranchFlow() -> some View {
        UIKitBranchView(onSelect: { self.showLabFlow($0) })
    }

    @ViewBuilder
    private func makeLabPlaceholderFlow(_ entry: FlowEntry) -> some View {
        switch entry.kind {
        case .swiftUI:
            makeSwiftUIPlaceholder(entry)
        case .uiKit:
            makeUIKitPlaceholder(entry)
        }
    }

    @ViewBuilder
    private func makeLabStoryFlow(_ story: ViewModelStory) -> some View {
        switch story {
        case .style:
            makeNavigationStyleFlow()
        case .lateResult:
            makeLateResultFlow()
        case .noRouter:
            makeNoRouterFlow()
        case .preview:
            makePreviewHelpFlow()
        }
    }

    @ViewBuilder
    private func makeLabToolFlow(_ tool: LabTool) -> some View {
        switch tool {
        case .navigationTree:
            makeNavigationTreeFlow()
        case .eventLog:
            makeEventLogFlow()
        }
    }

    private func makeNavigationTreeFlow() -> some View {
        factory.makeNavigationTree()
    }

    private func makeEventLogFlow() -> some View {
        factory.makeEventLog()
    }

    private func makeNavigationStyleFlow() -> some View {
        NavigationStyleView(onTry: { self.showLabDemo(.style($0)) })
    }

    private func makeLateResultFlow() -> some View {
        LateResultView(
            demos: labDemos,
            onOpen: { self.showLabDemo(.lateResult) }
        )
    }

    // Not reached from the Lab, which opens this story full screen (see `showLabStory(_:)`). Here
    // the account stack is above the view, so its push finds that router.
    private func makeNoRouterFlow() -> some View {
        NoRouterView()
    }

    private func makePreviewHelpFlow() -> some View {
        PreviewHelpView()
    }

    private func makeSwiftUIPlaceholder(_ entry: FlowEntry) -> some View {
        PlaceholderView(entry: entry)
    }

    private func makeUIKitPlaceholder(_ entry: FlowEntry) -> some View {
        PlaceholderControllerView(entry: entry)
    }
}
