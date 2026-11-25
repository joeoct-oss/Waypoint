//
//  AccountDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleLab
import ExampleNavigation
import ExampleServices
import ExampleStore
import SwiftUI

// What the Account tab uses, from `AppServices.accountDependencies(gate:rules:describeTree:)`: the
// catalog the wish list's products come from, the session and store for the profile, orders and
// wish list, the saved addresses, the window's account gate and navigation rules, the issue and
// event logs Settings and the Lab show, what the Navigation Lab's demos use, the window's
// navigation tree as text, and the Products feature's wish list screen. The app hands in the wish
// list screen, so this feature never names Products' types (planning #445).
package struct AccountDependencies {
    package let catalog: any ProductCatalog
    package let session: Session
    package let store: LocalStore
    package let addresses: AddressBook
    package let gate: any SessionAccountGating
    package let rules: NavigationRules
    package let issues: IssueLog
    package let events: EventLog
    package let lab: LabDependencies
    package let describeTree: () -> String
    package let wishlistScreen: ([Product]) -> AnyView

    package init(
        catalog: any ProductCatalog,
        session: Session,
        store: LocalStore,
        addresses: AddressBook,
        gate: any SessionAccountGating,
        rules: NavigationRules,
        issues: IssueLog,
        events: EventLog,
        lab: LabDependencies,
        describeTree: @escaping () -> String,
        wishlistScreen: @escaping ([Product]) -> AnyView
    ) {
        self.catalog = catalog
        self.session = session
        self.store = store
        self.addresses = addresses
        self.gate = gate
        self.rules = rules
        self.issues = issues
        self.events = events
        self.lab = lab
        self.describeTree = describeTree
        self.wishlistScreen = wishlistScreen
    }
}
