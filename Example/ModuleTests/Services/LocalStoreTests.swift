//
//  LocalStoreTests.swift
//  ExampleServicesTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import ExampleTestSupport
import Foundation
import Testing

// A store made for a test keeps its data in a domain of its own, so tests never
// change what the app keeps between launches, and the app's data never leaks into a test.
struct LocalStoreTests {
    private static let lampID = 1

    // What the app keeps in its own domain, empty when it keeps nothing.
    private static func appData() -> NSDictionary {
        let none: [String: Any] = [:]
        let data = UserDefaults.standard.persistentDomain(forName: LocalStore.appDomain) ?? none
        return NSDictionary(dictionary: data)
    }

    @Test("Tests never touch the app's data")
    func testsNeverTouchAppData() {
        let appData = Self.appData()
        let store = TestStore.make()
        defer {
            store.clearAll()
        }

        store.cartProductIDs = [Self.lampID]
        store.wishlistProductIDs = [Self.lampID]
        store.account = .sample
        let appDataAfterWrites = Self.appData()
        store.clearAll()

        #expect(appDataAfterWrites == appData)
        #expect(Self.appData() == appData)
    }

    @Test("A test store starts empty")
    func testStoreStartsEmpty() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }

        #expect(store.account == nil)
        #expect(store.cartProductIDs.isEmpty)
        #expect(store.wishlistProductIDs.isEmpty)
        #expect(store.addresses == nil)
    }
}
