//
//  ProductsFactoryTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Testing
@testable import WaypointExample

// Shop and Search, built by `ProductsFactory` (planning #424): a product page shows the product the
// route names from the catalog it was given, and a route to a product the catalog lacks draws
// nothing.
struct ProductsFactoryTests {
    private static let mugID = 2
    private static let missingID = 999

    @Test
    func productDetailShowsRoutedProduct() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let factory = TestProducts.makeFactory(store: store, gate: FakeAccountGate(isSignedIn: true))

        let detail = makeDetail(with: factory, for: ProductRoute(id: Self.mugID))

        #expect(detail?.product.id == Self.mugID)
    }

    @Test
    func unknownProductDrawsNothing() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let factory = TestProducts.makeFactory(store: store, gate: FakeAccountGate(isSignedIn: true))

        let detail = makeDetail(with: factory, for: ProductRoute(id: Self.missingID))

        #expect(detail == nil)
    }

    private func makeDetail(
        with factory: ProductsFactory,
        for route: ProductRoute
    ) -> ProductDetailView<EmptyView>? {
        factory.makeProductDetail(
            for: route,
            onAddToCart: { _ in },
            onSave: { _ in },
            related: { _ in EmptyView() }
        )
    }
}
