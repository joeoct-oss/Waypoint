//
//  AppServicesTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointCore
@testable import WaypointExample

// The app's one container (#301): every feature gets its services from it, so they share one copy
// of each, and Clear all data resets all of them. Each test runs on a store of its own, so it never
// reads or changes the app's data.
struct AppServicesTests {
    private static let lampID = 1
    private static let mugID = 2

    @Test
    func clearAllDataResetsEveryService() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let services = AppServices(
            launch: TestStore.launchOptions(),
            store: store
        )
        let office = Address.new(
            label: "Office",
            street: "9 Nova Lane",
            city: "Springfield",
            postcode: "40300"
        )
        services.session.signIn(.sample)
        services.addresses.add(office)
        store.cartProductIDs = [Self.lampID]
        store.wishlistProductIDs = [Self.mugID]

        services.clearAll()

        #expect(!services.session.isSignedIn)
        #expect(store.cartProductIDs.isEmpty)
        #expect(store.wishlistProductIDs.isEmpty)
        #expect(services.addresses.addresses == Address.samples)
    }

    @Test
    func screensShareOneAppWideStore() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let services = AppServices(
            launch: TestStore.launchOptions(),
            store: store
        )
        let gate = AccountGate(
            session: services.session,
            service: services.auth,
            tabs: TabRouter(selection: MainTab.shop)
        )
        let products = services.productsDependencies(
            gate: gate,
            launch: TestStore.launchOptions()
        )
        let cart = services.cartDependencies(gate: gate)

        products.store.cartProductIDs = [Self.lampID]

        let inCart = cart.catalog.products(withIDs: cart.store.cartProductIDs)
        let expected = [
            Self.lampID,
        ]
        #expect(inCart.map(\.id) == expected)
    }
}
