//
//  SearchModelTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointCore
@testable import WaypointExample

// Search's view model navigates on its own (#282): a tapped result pushes the product through the
// stack's navigator scoped to the shop, on a real router with no screen. A navigator scoped to
// another flow is reported, because the shop's stack declares `ShopFlow`.
@MainActor
struct SearchModelTests {
    private static let lampID = 1
    private static let shopFlowID = FlowID("search")

    @Test
    func searchModelPushesProduct() throws {
        let router = makeShopRouter(logging: .default)
        let model = SearchModel(navigation: router.navigator.scoped(to: ShopFlow.self))
        let lamp = try #require(Product.find(id: Self.lampID))

        let outcome = model.select(lamp)

        let expected = [
            AnyRoute(ProductRoute(id: Self.lampID)),
        ]
        #expect(outcome.didChange)
        #expect(router.state.path == expected)
    }

    @Test
    func scopedNavigatorRefusesOtherFlow() {
        let handler = IssueRecorder()
        let router = makeShopRouter(logging: LogConfiguration(handler: handler))

        _ = router.navigator.scoped(to: OtherFlow.self)

        #expect(handler.messages.contains { $0.contains(OtherFlow.mismatch) })
    }

    // A stack like Search's: it declares the shop and knows the product route.
    private func makeShopRouter(logging: LogConfiguration) -> StackRouter {
        let configuration = NavigationConfiguration(logging: logging)
        let router = StackRouter(
            flow: Self.shopFlowID,
            configuration: configuration
        )
        router.register(ProductRoute.self)
        router.declareFlow(ShopFlow.self)
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
// - `@unchecked Sendable`, because a handler can be called from any thread; `stored` is read and
//   written only under `lock`.
private final class IssueRecorder: LogHandler, @unchecked Sendable {
    private let lock = NSLock()
    // `var` because each issue logged adds its text. Only `log(_:)` changes it, under `lock`.
    private var stored: [String] = []

    var messages: [String] {
        lock.withLock { stored }
    }

    func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        category == .issues
    }

    func log(_ message: LogMessage) {
        lock.withLock { stored.append(message.text) }
    }
}
