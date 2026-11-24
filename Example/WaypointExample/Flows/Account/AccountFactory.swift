//
//  AccountFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Builds the Account tab from `AccountDependencies`: the tab's coordinator, Account, orders, the
// wish list, the addresses and the new address form, Settings, the Navigation Lab and its tools,
// and the Lab's demos through `LabFactory`. The coordinator passes in what each screen reports, so
// navigation stays in the coordinator.
struct AccountFactory {
    // The pushed wish list suggests nothing; only the wish list sheet on Shop does.
    private static let noSuggestions: [Product] = []

    private let dependencies: AccountDependencies

    init(dependencies: AccountDependencies) {
        self.dependencies = dependencies
    }

    // The Account tab on `router`, the stack the main tabs give it, opened as `launch` asks. Clear
    // all data runs `onClearAllData`.
    func makeCoordinator(
        router: StackRouter,
        launch: LaunchOptions,
        onClearAllData: @escaping () -> Void
    ) -> AccountCoordinator {
        AccountCoordinator(
            router: router,
            launch: launch,
            dependencies: dependencies,
            factory: self,
            onClearAllData: onClearAllData
        )
    }

    // The Lab's demos, whose reviews take `reviewsDelay` to load, or the usual delay for `nil`.
    func makeLabDemos(reviewsDelay: Duration?) -> LabDemoCoordinator {
        LabFactory(dependencies: dependencies.lab).makeDemos(reviewsDelay: reviewsDelay)
    }

    func makeAccount(
        onSignIn: @escaping () -> Void,
        onShowOrders: @escaping () -> Void,
        onShowWishlist: @escaping () -> Void,
        onShowAddresses: @escaping () -> Void,
        onShowSettings: @escaping () -> Void
    ) -> AccountView {
        let store = dependencies.store
        return AccountView(
            account: dependencies.session.account,
            wishlistCount: { store.wishlistProductIDs.count },
            onSignIn: onSignIn,
            onShowOrders: onShowOrders,
            onShowWishlist: onShowWishlist,
            onShowAddresses: onShowAddresses,
            onShowSettings: onShowSettings
        )
    }

    func makeOrders(onSelect: @escaping (Order) -> Void) -> OrdersView {
        OrdersView(onSelect: onSelect)
    }

    func makeOrder(_ order: Order) -> OrderDetailView {
        OrderDetailView(order: order)
    }

    // The products the store keeps on the wish list, from the catalog, with no suggestions.
    func makeWishlist() -> WishlistView {
        WishlistView(
            products: dependencies.catalog.products(withIDs: dependencies.store.wishlistProductIDs),
            suggestions: Self.noSuggestions,
            onSave: nil,
            onDone: nil
        )
    }

    func makeAddresses(onAddAddress: @escaping () -> Void) -> AddressesView {
        AddressesView(
            addresses: dependencies.addresses.addresses,
            onAddAddress: onAddAddress
        )
    }

    // The new address form, which always keeps the address, so it doesn't ask.
    func makeAddAddress(onSave: @escaping (Address) -> Void) -> AddAddressView {
        AddAddressView(
            asksToKeep: false,
            onSave: { address, _ in onSave(address) }
        )
    }

    func makeSettings(
        onShowLab: @escaping () -> Void,
        onClearAllData: @escaping () -> Void,
        onSignOut: @escaping () -> Void,
        rules: SettingsRules
    ) -> SettingsView {
        SettingsView(
            isSignedIn: dependencies.session.account != nil,
            onShowLab: onShowLab,
            onClearAllData: onClearAllData,
            onSignOut: onSignOut,
            rules: rules
        )
    }

    func makeLab(
        onSelectBranch: @escaping (Branch) -> Void,
        onSelectStory: @escaping (ViewModelStory) -> Void,
        onSelectTool: @escaping (LabTool) -> Void
    ) -> LabView {
        LabView(
            onSelectBranch: onSelectBranch,
            onSelectStory: onSelectStory,
            eventCount: dependencies.events.entries.count,
            onSelectTool: onSelectTool
        )
    }

    func makeNavigationTree() -> NavigationTreeView {
        NavigationTreeView(tree: dependencies.describeTree())
    }

    func makeEventLog() -> EventLogView {
        EventLogView(entries: dependencies.events.entries)
    }
}
