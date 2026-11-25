//
//  AccountFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleAddresses
import ExampleCatalog
import ExampleNavigation
import ExampleStore
import SwiftUI
import Waypoint

// Builds the Account tab from `AccountDependencies`: the tab's coordinator, Account, orders, the
// wish list, the addresses and the new address form, Settings, the Navigation Lab and its tools,
// and the Lab's screens and demos through `LabFactory`. The coordinator passes in what each screen
// reports, so navigation stays in the coordinator.
struct AccountFactory {
    // What the feature uses, which its coordinator reads too.
    let dependencies: AccountDependencies

    init(dependencies: AccountDependencies) {
        self.dependencies = dependencies
    }

    // The Account tab, opened as `launch` asks. Waypoint makes its router, which the main tabs make
    // the stack every tab shares. Clear all data runs `onClearAllData`.
    func makeCoordinator(
        launch: LaunchOptions,
        onClearAllData: @escaping () -> Void
    ) -> AccountCoordinator {
        AccountCoordinator(
            factory: self,
            launch: launch,
            onClearAllData: onClearAllData
        )
    }

    // Builds the Lab's screens and demos, which the Account tab shows.
    var lab: LabFactory {
        LabFactory(dependencies: dependencies.lab)
    }

    // The Lab's demos, whose reviews take `reviewsDelay` to load, or the usual delay for `nil`.
    func makeLabDemos(reviewsDelay: Duration?) -> LabDemoCoordinator {
        lab.makeDemos(reviewsDelay: reviewsDelay)
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

    // The products the store keeps on the wish list, from the catalog.
    func wishlistProducts() -> [Product] {
        dependencies.catalog.products(withIDs: dependencies.store.wishlistProductIDs)
    }

    // The Products feature's wish list screen, listing `wishlistProducts()`.
    func makeWishlist() -> AnyView {
        dependencies.wishlistScreen(wishlistProducts())
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
        tries: SettingsTries
    ) -> SettingsView {
        let navigationRules = dependencies.rules
        let rules = SettingsRules(
            pushesTwice: navigationRules.duplicatePushRule == .allow,
            queueLimit: navigationRules.queueLimit,
            failureCount: dependencies.issues.failureCount,
            onSetPushesTwice: { navigationRules.setPushesTwice($0) },
            onTryPushTwice: tries.pushTwice,
            onTryMissingPop: tries.missingPop,
            onTryPresentTwice: tries.presentTwice,
            onTryUnrecovered: tries.unrecovered
        )
        return SettingsView(
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

    // A Lab tool: the window's navigation tree as text, or the event log.
    @ViewBuilder
    func makeLabTool(_ tool: LabTool) -> some View {
        switch tool {
        case .navigationTree:
            NavigationTreeView(tree: dependencies.describeTree())
        case .eventLog:
            EventLogView(entries: dependencies.events.entries)
        }
    }
}
