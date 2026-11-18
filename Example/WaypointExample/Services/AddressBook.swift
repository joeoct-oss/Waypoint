//
//  AddressBook.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The reader's saved delivery addresses, shared by checkout and Account, Addresses. The local store
// keeps them between launches, and a fresh install starts with the two samples.
//
// Conformances:
// - `Observable` (from `@Observable`), so checkout and Account redraw when an address is added.
@MainActor
@Observable
final class AddressBook {
    private let store: LocalStore
    // `var` because `add(_:)` adds to it and `reload()` reads it again after Clear all data.
    private(set) var addresses: [Address]

    init(store: LocalStore) {
        self.store = store
        addresses = store.addresses ?? Address.samples
    }

    func add(_ address: Address) {
        addresses.append(address)
        store.addresses = addresses
    }

    func reload() {
        addresses = store.addresses ?? Address.samples
    }
}
