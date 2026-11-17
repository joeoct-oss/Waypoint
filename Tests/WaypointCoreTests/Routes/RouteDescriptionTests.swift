//
//  RouteDescriptionTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointCore
import WaypointTestSupport

/// Pins how routes, keys and decoding errors print (decision 0010, amended by 0011).
@Suite("Route descriptions")
struct RouteDescriptionTests {
    typealias SearchRoute = RouteFixtures.SearchRoute

    typealias PaymentRoute = RouteFixtures.PaymentRoute

    @Test
    func structFieldsArePrivateByDefault() {
        #expect(AnyRoute(ProductRoute(id: 42)).description == "ProductRoute(id: <private>)")
    }

    @Test
    func routeWithoutFieldsPrintsTypeName() {
        #expect(AnyRoute(HomeRoute()).description == "HomeRoute")
    }

    @Test
    func publicLogFieldsAreShown() {
        let route = AnyRoute(SearchRoute(id: 42, query: "shoes"))

        #expect(route.description == "RouteFixtures.SearchRoute(id: 42, query: <private>)")
    }

    @Test
    func revealingShowsEveryField() {
        let route = AnyRoute(SearchRoute(id: 42, query: "shoes"))
        let empty = AnyRoute(SearchRoute(id: 1, query: nil))

        let revealed = route.debugDescription(revealingPrivateValues: true)
        #expect(revealed == #"RouteFixtures.SearchRoute(id: 42, query: "shoes")"#)
        #expect(empty.debugDescription(revealingPrivateValues: true) == "RouteFixtures.SearchRoute(id: 1, query: nil)")
        #expect(route.debugDescription == route.description)
    }

    @Test
    func enumCasesPrintCaseName() {
        #expect(AnyRoute(WizardStep.payment).description == "WizardStep.payment")
        #expect(AnyRoute(PaymentRoute.cash).description == "RouteFixtures.PaymentRoute.cash")
    }

    @Test
    func enumPayloadsArePrivate() {
        let card = AnyRoute(PaymentRoute.card(id: 3, nickname: "Work"))
        let voucher = AnyRoute(PaymentRoute.voucher("SAVE10"))

        #expect(card.description == "RouteFixtures.PaymentRoute.card(id: <private>, nickname: <private>)")
        #expect(voucher.description == "RouteFixtures.PaymentRoute.voucher(<private>)")
        let revealed = voucher.debugDescription(revealingPrivateValues: true)
        #expect(revealed == #"RouteFixtures.PaymentRoute.voucher("SAVE10")"#)
    }

    @Test
    func routesOwnDescriptionIsIgnored() {
        let route = AnyRoute(RouteFixtures.LeakyRoute(email: "a@b.c"))

        #expect(route.description == "RouteFixtures.LeakyRoute(email: <private>)")
    }

    @Test
    func routeKeyPrintsFullKey() {
        #expect(ProductRoute.routeKey.description == "WaypointTestSupport.ProductRoute")
    }

    @Test
    func decodingErrorsPrintOneLine() {
        let key = RouteKey("Shop.ProductRoute")

        #expect(RouteDecodingError.invalidPayload(key).description == "invalidPayload key=Shop.ProductRoute")
        #expect(RouteDecodingError.unstableRouteKey(key).description == "unstableRouteKey key=Shop.ProductRoute")
        #expect(RouteDecodingError.invalidRouteKey("").description == #"invalidRouteKey key="""#)
        let types = ["Shop.A", "Shop.B"]
        let duplicate = RouteDecodingError.duplicateRouteKey(key, types: types)
        #expect(duplicate.description == "duplicateRouteKey key=Shop.ProductRoute types=[Shop.A, Shop.B]")
    }
}
