//
//  Session.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//


import Observation

// Who is signed in, shared by every window. It saves the account to the local store, so the
// reader stays signed in between launches.
//
// Conformances:
// - `Observable` (from `@Observable`), so Account redraws when the reader signs in or out.
@MainActor
@Observable
final class Session {
    private let store: LocalStore
    // `var` because `signIn(_:)` and `signOut()` change it.
    private(set) var account: Account?

    var isSignedIn: Bool {
        account != nil
    }

    init(store: LocalStore) {
        self.store = store
        account = store.account
    }

    func signIn(_ account: Account) {
        self.account = account
        store.account = account
    }

    func signOut() {
        account = nil
        store.account = nil
    }
}
