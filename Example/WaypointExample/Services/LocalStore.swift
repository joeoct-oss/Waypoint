//
//  LocalStore.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//


import Foundation

// Everything the example app keeps between launches: the signed-in account, the accounts made on
// this device, the cart and the wish list. It lives in its own `UserDefaults` domain, so Clear all
// data in Settings removes all of it at once and leaves the system's own settings alone.
@MainActor
final class LocalStore {
    private static let domain = "dev.waypoint.example.data"

    private static func decodeAccount(_ data: Data) -> Account? {
        try? JSONDecoder().decode(Account.self, from: data)
    }

    private static func encodeAccount(_ account: Account) -> Data? {
        try? JSONEncoder().encode(account)
    }

    private let defaults: UserDefaults

    var account: Account? {
        get {
            defaults.data(forKey: Key.account.rawValue).flatMap(Self.decodeAccount)
        }
        set {
            defaults.set(newValue.flatMap(Self.encodeAccount), forKey: Key.account.rawValue)
        }
    }

    var registeredEmails: [String] {
        get {
            defaults.stringArray(forKey: Key.registeredEmails.rawValue) ?? []
        }
        set {
            defaults.set(newValue, forKey: Key.registeredEmails.rawValue)
        }
    }

    var cartProductIDs: [Int] {
        get {
            defaults.array(forKey: Key.cart.rawValue) as? [Int] ?? []
        }
        set {
            defaults.set(newValue, forKey: Key.cart.rawValue)
        }
    }

    var wishlistProductIDs: [Int] {
        get {
            defaults.array(forKey: Key.wishlist.rawValue) as? [Int] ?? []
        }
        set {
            defaults.set(newValue, forKey: Key.wishlist.rawValue)
        }
    }

    init() {
        defaults = UserDefaults(suiteName: Self.domain) ?? .standard
    }

    func clearAll() {
        defaults.removePersistentDomain(forName: Self.domain)
    }
}

extension LocalStore {
    // The keys the store saves under.
    //
    // Conformances:
    // - `String` raw values, so each key is its `UserDefaults` key.
    private enum Key: String {
        case account
        case registeredEmails
        case cart
        case wishlist
    }
}
