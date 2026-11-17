//
//  RouteTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointCore
import WaypointTestSupport

/// Typed routes, erased routes, keys and the registry (#10).
@Suite("Routes")
struct RouteTests {
    typealias PaymentRoute = RouteFixtures.PaymentRoute

    typealias OrderRoute = RouteFixtures.OrderRoute

    @Test
    func routesWithSameValuesAreEqual() {
        #expect(PaymentRoute.card(id: 1, nickname: "Work") == .card(id: 1, nickname: "Work"))
        #expect(PaymentRoute.card(id: 1, nickname: "Work") != .card(id: 2, nickname: "Work"))
        #expect(Set([PaymentRoute.cash, .cash, .voucher("A")]).count == 2)
    }

    @Test
    func routeRoundTripsThroughJSON() throws {
        let route = PaymentRoute.card(id: 7, nickname: "Home")

        let decoded = try JSONDecoder().decode(PaymentRoute.self, from: JSONEncoder().encode(route))

        #expect(decoded == route)
    }

    @Test
    func routeKeyIsModuleAndTypeName() {
        #expect(ProductRoute.routeKey.rawValue == "WaypointTestSupport.ProductRoute")
        #expect(OrderRoute.routeKey.rawValue == "WaypointCoreTests.RouteFixtures.OrderRoute")
        #expect(RouteFixtures.Box<Int>.routeKey.rawValue == "WaypointCoreTests.RouteFixtures.Box<Swift.Int>")
        #expect(RouteKey(ProductRoute.self) == ProductRoute.routeKey)
    }

    @Test
    func sameTypeNameInTwoModulesGivesTwoKeys() {
        #expect(ProductRoute.routeKey != RouteFixtures.ProductRoute.routeKey)
    }

    @Test
    func routeKeyTypeNameDropsModule() {
        #expect(ProductRoute.routeKey.typeName == "ProductRoute")
        #expect(OrderRoute.routeKey.typeName == "RouteFixtures.OrderRoute")
        #expect(RouteFixtures.Box<Int>.routeKey.typeName == "RouteFixtures.Box<Swift.Int>")
        #expect(hiddenRouteKey.typeName == "HiddenRoute")
    }

    @Test
    func routeKeyEncodesAsPlainString() throws {
        let data = try JSONEncoder().encode(ProductRoute.routeKey)

        #expect(String(decoding: data, as: UTF8.self) == "\"WaypointTestSupport.ProductRoute\"")
        #expect(try JSONDecoder().decode(RouteKey.self, from: data) == ProductRoute.routeKey)
    }

    @Test
    func formerRouteKeyDecodes() throws {
        let saved = Data(#"{"route":"WaypointCoreTests.OldOrderRoute","value":{"id":5}}"#.utf8)

        let route = try decoder(registering: OrderRoute.self).decode(AnyRoute.self, from: saved)

        #expect(route == AnyRoute(OrderRoute(id: 5)))
    }

    @Test
    func encodingUsesCurrentKey() throws {
        let data = try JSONEncoder().encode(AnyRoute(OrderRoute(id: 5)))
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("WaypointCoreTests.RouteFixtures.OrderRoute"))
        #expect(!json.contains("OldOrderRoute"))
    }

    @Test
    func formerKeyOfAnotherRouteReportsDuplicate() throws {
        let registry = RouteRegistry()
            .registering(OrderRoute.self)
            .registering(RouteFixtures.ClashingRoute.self)

        let key = OrderRoute.routeKey
        let clashing = RouteFixtures.ClashingRoute.routeKey.rawValue
        #expect(registry.problems == [.duplicateRouteKey(key, types: [key.rawValue, clashing])])
        #expect(registry.type(for: key) == OrderRoute.self)
    }

    @Test
    func privateRouteReportsUnstableKey() {
        let registry = registeringHiddenRoute(in: RouteRegistry())

        #expect(registry.problems == [.unstableRouteKey(hiddenRouteKey)])
        #expect(throws: RouteDecodingError.unstableRouteKey(hiddenRouteKey)) {
            try JSONEncoder().encode(hiddenRoute)
        }
    }

    @Test
    func emptyFormerKeyReportsInvalid() {
        let registry = RouteRegistry()
            .registering(RouteFixtures.EmptyFormerKeyRoute.self)

        #expect(registry.problems == [.invalidRouteKey("")])
        #expect(registry.isRegistered(RouteFixtures.EmptyFormerKeyRoute.self))
    }

    @Test
    func registeringTwiceDoesNothing() {
        let registry = RouteRegistry()
            .registering(OrderRoute.self)
            .registering(OrderRoute.self)

        #expect(registry.problems.isEmpty)
        #expect(registry.registeredTypes.count == 1)
    }

    @Test
    func unknownKeyMessageSuggestsFormerKey() {
        let error = RouteDecodingError.unknownRouteKey(RouteKey("Shop.OldProductRoute"))

        #expect(error.description == "unknownRouteKey key=Shop.OldProductRoute")
        #expect(error.debugDescription.contains(#"add RouteKey("Shop.OldProductRoute") to the new type's formerRouteKeys"#))
    }

    @Test
    func anyRouteEqualityRespectsType() {
        #expect(AnyRoute(OrderRoute(id: 1)) != AnyRoute(RouteFixtures.InvoiceRoute(id: 1)))
        #expect(AnyRoute(OrderRoute(id: 1)) == AnyRoute(OrderRoute(id: 1)))
        #expect(Set([AnyRoute(OrderRoute(id: 1)), AnyRoute(OrderRoute(id: 1))]).count == 1)
    }

    @Test
    func anyRouteUnwrapsToOriginalType() {
        let route = AnyRoute(ProductRoute(id: 42))

        #expect(route.as(ProductRoute.self) == ProductRoute(id: 42))
        #expect(route.as(HomeRoute.self) == nil)
        #expect(route.is(ProductRoute.self))
        #expect(!route.is(HomeRoute.self))
        #expect(route.routeKey == ProductRoute.routeKey)
    }

    @Test
    func registryDecodesRegisteredType() throws {
        let original = AnyRoute(PaymentRoute.card(id: 3, nickname: "Travel"))
        let data = try JSONEncoder().encode([original])

        let decoded = try decoder(registering: PaymentRoute.self).decode([AnyRoute].self, from: data)

        #expect(decoded == [original])
    }

    @Test
    func registryReportsUnknownKey() throws {
        let data = try JSONEncoder().encode(AnyRoute(ProductRoute(id: 1)))

        #expect(throws: RouteDecodingError.unknownRouteKey(ProductRoute.routeKey)) {
            try decoder(registering: OrderRoute.self).decode(AnyRoute.self, from: data)
        }
    }

    @Test
    func registryReportsRemovedCase() {
        let saved = Data(#"{"route":"WaypointCoreTests.RouteFixtures.PaymentRoute","value":{"giftCard":{}}}"#.utf8)

        #expect(throws: RouteDecodingError.invalidPayload(PaymentRoute.routeKey)) {
            try decoder(registering: PaymentRoute.self).decode(AnyRoute.self, from: saved)
        }
    }

    @Test
    func decodingWithoutRegistryFailsWithoutCrashing() throws {
        let data = try JSONEncoder().encode(AnyRoute(ProductRoute(id: 1)))

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AnyRoute.self, from: data)
        }
    }

    @Test
    func anyRouteIsSendableAcrossActors() async {
        let route = AnyRoute(ProductRoute(id: 9))

        let returned = await Task.detached { route }.value

        #expect(returned == route)
    }

    // A decoder with a registry that knows one route type.
    private func decoder<R: Route>(registering type: R.Type) -> JSONDecoder {
        let registry = RouteRegistry()
            .registering(type)
        let decoder = JSONDecoder()
        decoder.userInfo[.routeRegistry] = registry
        return decoder
    }
}
