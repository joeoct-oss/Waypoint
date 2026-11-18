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
// Conformances:
// - `Observable` (from `@Observable`), so `AccountFlowView` redraws when the path changes.
@MainActor
@Observable
final class AccountCoordinator {
    private let session: Session
    private let addressBook: AddressBook
    private let gate: AccountGate
    private let onClearAllData: () -> Void
    // Runs the Lab's view and view-model demos, each full screen on a Waypoint stack of its own.
    let labDemos: LabDemoCoordinator
    // `var` because the `show…()` functions push onto it, and `syncPath(_:)` takes the pops the
    // stack makes itself.
    private(set) var path: [AccountScreen]

    init(
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
        labDemos = LabDemoCoordinator(navigation: navigation)
        path = Self.makePath(for: launch)
    }

    // A launch that opens the Lab starts on it, or on one of its branches or entries.
    private static func makePath(for launch: LaunchOptions) -> [AccountScreen] {
        guard launch.opensLab else {
            return []
        }
        let lab: [AccountScreen] = [.settings, .lab]
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
            trail: AccountScreen.rootTrail
        )
    }

    func makeDestination(for screen: AccountScreen) -> some View {
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
        path.append(.orders)
    }

    func showOrder(_ order: Order) {
        path.append(.order(order))
    }

    func openAddresses() {
        gate.requireAccount { self.showAddresses() }
    }

    func showAddresses() {
        path.append(.addresses)
    }

    func showAddAddress() {
        path.append(.addAddress)
    }

    // Keeps the form's address in the address book and goes back to the list.
    func addAddress(_ address: Address) {
        addressBook.add(address)
        path.removeLast()
    }

    func showSettings() {
        path.append(.settings)
    }

    func showLab() {
        path.append(.lab)
    }

    func showLabBranch(_ branch: Branch) {
        path.append(.labBranch(branch))
    }

    func showLabFlow(_ entry: FlowEntry) {
        path.append(.labFlow(entry))
    }

    func showLabStory(_ story: ViewModelStory) {
        path.append(.labStory(story))
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

    func syncPath(_ newPath: [AccountScreen]) {
        path = newPath
    }

    @ViewBuilder
    private func makeScreen(for screen: AccountScreen) -> some View {
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
