//
//  MainCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleAccount
import ExampleNavigation
import ExampleProducts
import ExampleServices
import ExampleStore
import ExampleTestSupport
import Testing
import WaypointCore

@testable import WaypointExample

// The main tabs: `MainFactory` builds the main coordinator and each tab's
// coordinator, and the main coordinator is a `TabCoordinator` around one stack every tab shares.
// Every tab's coordinator drives that one stack, so no tab holds a stack another tab owns, and a
// launch into the Lab opens it on that stack.
struct MainCoordinatorTests {
    private static let lampID = 1

    @Test("Every tab drives the shared stack")
    func everyTabDrivesTheSharedStack() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let main = makeMain(store: store, launch: TestStore.launchOptions())
        let lamp = try #require(Product.find(id: Self.lampID))

        main.shop.showProduct(lamp)

        let stack = main.sharedStack
        #expect(main.shop.router === stack)
        #expect(main.search.router === stack)
        #expect(main.cart.router === stack)
        #expect(main.account.router === stack)
        let expected = [
            AnyRoute(ProductRoute(id: Self.lampID))
        ]
        #expect(stack.state.path == expected)
    }

    @Test("Add to cart opens the cart with the product and updates its badge")
    func addToCartOpensCartWithTheProduct() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let main = makeMain(store: store, launch: TestStore.launchOptions())
        let lamp = try #require(Product.find(id: Self.lampID))

        main.shop.addToCart(lamp)

        let expected = [
            Self.lampID
        ]
        #expect(main.router.selection == .cart)
        #expect(main.cart.products.map(\.id) == expected)
        #expect(main.badge(for: .cart) == expected.count)
    }

    @Test("Launching into the lab opens the account tab on the lab")
    func labLaunchOpensAccountOnTheLab() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }

        let main = makeMain(store: store, launch: TestStore.launchOptions(opensLab: true))

        let expected = [
            AnyRoute(AccountRoute.settings),
            AnyRoute(AccountRoute.lab),
        ]
        #expect(main.router.selection == .account)
        #expect(main.sharedStack.state.path == expected)
    }

    private func makeMain(
        store: LocalStore,
        launch: LaunchOptions
    ) -> MainCoordinator {
        let services = AppServices(
            launch: launch,
            store: store
        )
        return MainFactory(services: services, launch: launch).makeCoordinator(onClearAllData: { })
    }
}
