//
//  CartDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleServices
import ExampleStore

// What the Cart tab and checkout use, from `AppServices.cartDependencies(gate:)`: the catalog the
// cart's products come from, the store that keeps the cart and the orders, the saved addresses, and
// the window's account gate for Check out.
package struct CartDependencies {
    package let catalog: any ProductCatalog
    package let store: LocalStore
    package let addresses: AddressBook
    package let gate: any AccountGating

    package init(
        catalog: any ProductCatalog,
        store: LocalStore,
        addresses: AddressBook,
        gate: any AccountGating
    ) {
        self.catalog = catalog
        self.store = store
        self.addresses = addresses
        self.gate = gate
    }
}
