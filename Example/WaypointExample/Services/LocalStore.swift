//
//  LocalStore.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//


import Foundation

// Everything the example app keeps between launches: the signed-in account, the accounts made on
// this device, the cart, the wish list and the saved addresses. It lives in its own `UserDefaults`
// domain, so Clear all data in Settings removes all of it at once and leaves the system's own
// settings alone.
@MainActor
final class LocalStore {
    private static let domain = "dev.waypoint.example.data"

    private static func decodeAccount(_ data: Data) -> Account? {
        try? JSONDecoder().decode(Account.self, from: data)
    }

    private static func encodeAccount(_ account: Account) -> Data? {
        try? JSONEncoder().encode(account)
    }

    private static func decodeAddresses(_ data: Data) -> [Address]? {
        try? JSONDecoder().decode([Address].self, from: data)
    }

    private static func encodeAddresses(_ addresses: [Address]) -> Data? {
        try? JSONEncoder().encode(addresses)
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

    // `nil` until the reader saves an address, so a fresh install starts with the samples.
    var addresses: [Address]? {
        get {
            defaults.data(forKey: Key.addresses.rawValue).flatMap(Self.decodeAddresses)
        }
        set {
            defaults.set(newValue.flatMap(Self.encodeAddresses), forKey: Key.addresses.rawValue)
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
        case addresses
    }
}
