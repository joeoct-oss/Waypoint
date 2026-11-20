//
//  AccountCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import WaypointCore

// The account tab: the profile at the root (or Sign in for a guest), orders, addresses and settings
// pushed above it, and the Navigation Lab under settings with the twenty demo entries. Orders and
// Addresses need an account, so the account gate asks a guest to sign in first. Add a new address
// pushes the form; saving keeps the address in the address book, which checkout shares, and goes
// back to the list. Sign out ends the session and leaves
// the reader where they are, as a guest. Clear all data reports to the app coordinator, which
// clears the store and starts the window over.
//
// The stack runs on Waypoint: `router` is the account tab's stack router from the main tab router,
// `AccountFlowView` draws it with `WaypointStack`, and each screen above the root is an
// `AccountRoute`, so the journey lines follow the reader through Account too.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AccountFlowView` redraws when the account changes.
@MainActor
@Observable
final class AccountCoordinator {
    let router: StackRouter
    private let session: Session
    private let addressBook: AddressBook
    private let gate: AccountGate
    private let onClearAllData: () -> Void
    // Runs the Lab's view and view-model demos, each full screen on a Waypoint stack of its own.
    let labDemos: LabDemoCoordinator

    init(
        router: StackRouter,
        launch: LaunchOptions,
        session: Session,
        addressBook: AddressBook,
        gate: AccountGate,
        navigation: NavigationConfiguration,
        onClearAllData: @escaping () -> Void
    ) {
        self.session = session
        self.addressBook = addressBook
        self.gate = gate
        self.onClearAllData = onClearAllData
        self.router = router
        labDemos = LabDemoCoordinator(navigation: navigation)
        router.setRootName(MainTab.account.title)
        router.setCoordinator(self)
        openLaunchPath(launch)
    }

    // A launch that opens the Lab starts on it, or on one of its branches or entries. The route is
    // registered first, because the stack isn't drawn yet and the registry is strict.
    private func openLaunchPath(_ launch: LaunchOptions) {
        let path = Self.makePath(for: launch)
        guard !path.isEmpty else {
            return
        }
        router.register(AccountRoute.self)
        router.setPath {
            for route in path {
                route
            }
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
        guard let entry = launch.entry else {
            return lab + [.labBranch(branch)]
        }
        return lab + [.labBranch(branch), .labFlow(entry)]
    }

    func makeAccountFlow() -> some View {
        AccountView(
            account: session.account,
            onSignIn: { self.showSignIn() },
            onShowOrders: { self.openOrders() },
            onShowAddresses: { self.openAddresses() },
            onShowSettings: { self.showSettings() },
            onSignOut: { self.signOut() }
        )
        .screenChrome(
            title: MainTab.account.title,
            kind: nil,
            trail: AccountRoute.rootTrail
        )
    }

    func makeDestination(for screen: AccountRoute) -> some View {
        makeScreen(for: screen)
            .screenChrome(
                title: screen.title,
                kind: screen.kind,
                trail: screen.trail
            )
    }

    func showSignIn() {
        gate.showSignIn()
    }

    func openOrders() {
        gate.requireAccount { self.showOrders() }
    }

    func showOrders() {
        router.push(AccountRoute.orders)
    }

    func showOrder(_ order: Order) {
        router.push(AccountRoute.order(order))
    }

    func openAddresses() {
        gate.requireAccount { self.showAddresses() }
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

    func showLabFlow(_ entry: FlowEntry) {
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

    func showLabDemo(_ demo: LabDemo) {
        labDemos.showDemo(demo)
    }

    func signOut() {
        session.signOut()
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
        }
    }

    private func makeOrdersFlow() -> some View {
        OrdersView(onSelect: { self.showOrder($0) })
    }

    private func makeOrderFlow(_ order: Order) -> some View {
        OrderDetailView(order: order)
    }

    private func makeAddressesFlow() -> some View {
        AddressesView(
            addresses: addressBook.addresses,
            onAddAddress: { self.showAddAddress() }
        )
    }

    private func makeAddAddressFlow() -> some View {
        AddAddressView(
            asksToKeep: false,
            onSave: { address, _ in self.addAddress(address) }
        )
    }

    private func makeSettingsFlow() -> some View {
        SettingsView(
            onShowLab: { self.showLab() },
            onClearAllData: { self.clearAllData() }
        )
    }

    private func makeLabFlow() -> some View {
        LabView(
            onSelectBranch: { self.showLabBranch($0) },
            onSelectStory: { self.showLabStory($0) }
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
