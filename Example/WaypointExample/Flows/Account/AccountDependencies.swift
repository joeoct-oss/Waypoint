//
//  AccountDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// What the Account tab uses, from `AppServices.accountDependencies(gate:rules:describeTree:)`: the
// catalog the wish list's products come from, the session and store for the profile, orders and
// wish list, the saved addresses, the window's account gate and navigation rules, the issue and
// event logs Settings and the Lab show, what the Navigation Lab's demos use, the window's
// navigation tree as text, and the Products feature's wish list screen. The app hands in the wish
// list screen, so this feature never names Products' types (planning #445).
struct AccountDependencies {
    let catalog: any ProductCatalog
    let session: Session
    let store: LocalStore
    let addresses: AddressBook
    let gate: any SessionAccountGating
    let rules: NavigationRules
    let issues: IssueLog
    let events: EventLog
    let lab: LabDependencies
    let describeTree: () -> String
    let wishlistScreen: ([Product]) -> AnyView
}
