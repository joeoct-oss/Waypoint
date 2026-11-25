//
//  AccountFactoryTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import Testing
import WaypointCore
@testable import WaypointExample

// The Account tab, built by `AccountFactory` (planning #424): the pushed wish list lists the
// products the store keeps, from the catalog the factory was given.
struct AccountFactoryTests {
    private static let mugID = 2
    private static let missingID = 999

    @Test("The wishlist lists the saved products from the catalog")
    func wishlistListsSavedProductsFromTheCatalog() {
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
            factory: AuthFactory(dependencies: services.authDependencies()),
            tabs: TabRouter(selection: MainTab.account)
        )
        let dependencies = services.accountDependencies(
            gate: gate,
            rules: NavigationRules(tabs: TabRouter(selection: MainTab.account)),
            describeTree: { "" }
        )
        store.wishlistProductIDs = [Self.mugID, Self.missingID]

        let products = AccountFactory(dependencies: dependencies).wishlistProducts()

        let expected = [
            Self.mugID,
        ]
        #expect(products.map(\.id) == expected)
    }
}
