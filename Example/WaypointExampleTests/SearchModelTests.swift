//
//  SearchModelTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import ExampleStore
import Foundation
import Testing
import Understudy
import WaypointCore
@testable import WaypointExample

// Search's view model navigates on its own (planning #417): a tapped result pushes the product
// through the stack's navigator scoped to the shop, on a real router with no screen. Each test
// builds the model with `ProductsFactory`, as the shop's coordinator does, so a stack that stops
// declaring `ShopFlow` fails here: the declared flow is checked, and a navigator scoped to another
// flow is no longer reported. The results come from the catalog the factory was given (planning
// #424).
struct SearchModelTests {
    private static let lampID = 1
    private static let mugID = 2
    private static let throwID = 3
    private static let shopFlowID = FlowID("search")

    @Test("Search finds only matching products")
    func searchFindsOnlyMatchingProducts() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let catalog = FixedCatalog(products: SampleCatalog().products(withIDs: catalogIDs()))
        let model = makeModel(store: store, catalog: catalog, on: makeShopRouter(logging: .default))

        let results = model.results(for: "mug")

        let expected = [
            Self.mugID,
        ]
        #expect(results.map(\.id) == expected)
    }

    @Test("The search model pushes the product on the shop flow")
    func searchModelPushesProduct() throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let router = makeShopRouter(logging: .default)
        let model = makeModel(store: store, catalog: SampleCatalog(), on: router)
        let lamp = try #require(Product.find(id: Self.lampID))

        let outcome = model.select(lamp)

        let expected = [
            AnyRoute(ProductRoute(id: Self.lampID)),
        ]
        let declared = router.declaredFlow.map(ObjectIdentifier.init)
        #expect(declared == ObjectIdentifier(ShopFlow.self))
        #expect(outcome.didChange)
        #expect(router.state.path == expected)
    }

    @Test("A navigator scoped to another flow logs a mismatch")
    func scopedNavigatorRefusesOtherFlow() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let handler = IssueRecorder()
        let router = makeShopRouter(logging: LogConfiguration(handler: handler))
        _ = makeModel(store: store, catalog: SampleCatalog(), on: router)

        _ = router.navigator.scoped(to: OtherFlow.self)

        #expect(handler.logged.calls.contains { $0.contains(OtherFlow.mismatch) })
    }

    private func catalogIDs() -> [Int] {
        [
            Self.lampID,
            Self.mugID,
            Self.throwID,
        ]
    }

    private func makeModel(
        store: LocalStore,
        catalog: any ProductCatalog,
        on router: StackRouter
    ) -> SearchModel {
        let factory = TestProducts.makeFactory(
            store: store,
            gate: FakeAccountGate(isSignedIn: false),
            catalog: catalog
        )
        return factory.makeSearchModel(on: router)
    }

    // A stack like Search's: it knows the product route. The factory's model declares the shop.
    private func makeShopRouter(logging: LogConfiguration) -> StackRouter {
        let configuration = NavigationConfiguration(logging: logging)
        let router = StackRouter(
            flow: Self.shopFlowID,
            configuration: configuration
        )
        router.register(ProductRoute.self)
        return router
    }
}

// A flow that isn't the shop.
//
// Conformances:
// - `NavigationFlow`, so a navigator can be scoped to it.
private enum OtherFlow: NavigationFlow {
    // How the flow mismatch issue names this flow.
    static let mismatch = "OtherFlow.self"
}

// Keeps the text of every navigation issue a router logs.
//
// Conformances:
// - `LogHandler`, so a router logs to it.
// - `Sendable`, because a handler can be called from any thread; its one stored value is a spy of
//   strings, which is `Sendable`.
private final class IssueRecorder: LogHandler, Sendable {
    let logged = Spy<String, Void>()

    func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        category == .issues
    }

    func log(_ message: LogMessage) {
        logged(message.text)
    }
}

