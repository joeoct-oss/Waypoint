//
//  AccountCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The account tab: the profile at the root, orders and settings pushed above it, and the Navigation
// Lab under settings with the twenty demo entries. Sign out reports to the app coordinator, which
// switches the root back to sign in.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AccountFlowView` redraws when the path changes.
@MainActor
@Observable
final class AccountCoordinator {
    private let onSignOut: () -> Void
    // `var` because the `show…()` functions push onto it, and `syncPath(_:)` takes the pops the
    // stack makes itself.
    private(set) var path: [AccountScreen]

    init(
        launch: LaunchOptions,
        onSignOut: @escaping () -> Void
    ) {
        self.onSignOut = onSignOut
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
            onShowOrders: { self.showOrders() },
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

    func showOrders() {
        path.append(.orders)
    }

    func showOrder(_ order: Order) {
        path.append(.order(order))
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

    func signOut() {
        onSignOut()
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
        case .settings:
            makeSettingsFlow()
        case .lab:
            makeLabFlow()
        case .labBranch(let branch):
            makeLabBranchFlow(branch)
        case .labFlow(let entry):
            makeLabPlaceholderFlow(entry)
        }
    }

    private func makeOrdersFlow() -> some View {
        OrdersView(onSelect: { self.showOrder($0) })
    }

    private func makeOrderFlow(_ order: Order) -> some View {
        OrderDetailView(order: order)
    }

    private func makeSettingsFlow() -> some View {
        SettingsView(onShowLab: { self.showLab() })
    }

    private func makeLabFlow() -> some View {
        LabView(onSelectBranch: { self.showLabBranch($0) })
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

    private func makeSwiftUIPlaceholder(_ entry: FlowEntry) -> some View {
        PlaceholderView(entry: entry)
    }

    private func makeUIKitPlaceholder(_ entry: FlowEntry) -> some View {
        PlaceholderControllerView(entry: entry)
    }
}
