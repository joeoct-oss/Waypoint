//
//  CartDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// What the Cart tab and checkout use, from `AppServices.cartDependencies(gate:)`: the catalog the
// cart's products come from, the store that keeps the cart and the orders, the saved addresses, and
// the window's account gate for Check out.
struct CartDependencies {
    let catalog: any ProductCatalog
    let store: LocalStore
    let addresses: AddressBook
    let gate: AccountGate
}
