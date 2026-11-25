//
//  RouteTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointCore
import WaypointTestSupport

/// Typed routes, erased routes, keys and the registry (planning #264).
@Suite("Routes")
struct RouteTests {
    typealias PaymentRoute = RouteFixtures.PaymentRoute

    typealias OrderRoute = RouteFixtures.OrderRoute

    @Test("Routes with the same values are equal")
    func routesWithSameValuesAreEqual() {
        #expect(PaymentRoute.card(id: 1, nickname: "Work") == .card(id: 1, nickname: "Work"))
        #expect(PaymentRoute.card(id: 1, nickname: "Work") != .card(id: 2, nickname: "Work"))
        let payments: Set<PaymentRoute> = [.cash, .cash, .voucher("A")]
        #expect(payments.count == 2)
    }

    @Test("A route round-trips through JSON")
    func routeRoundTripsThroughJSON() throws {
        let route = PaymentRoute.card(id: 7, nickname: "Home")

        let decoded = try JSONDecoder().decode(PaymentRoute.self, from: JSONEncoder().encode(route))

        #expect(decoded == route)
    }

    @Test("A route key is the module and type name")
    func routeKeyIsModuleAndTypeName() {
        #expect(ProductRoute.routeKey.rawValue == "WaypointTestSupport.ProductRoute")
        #expect(OrderRoute.routeKey.rawValue == "WaypointCoreTests.RouteFixtures.OrderRoute")
        #expect(RouteFixtures.Box<Int>.routeKey.rawValue == "WaypointCoreTests.RouteFixtures.Box<Swift.Int>")
        #expect(RouteKey(ProductRoute.self) == ProductRoute.routeKey)
    }

    @Test("The same type name in two modules gives two keys")
    func sameTypeNameInTwoModulesGivesTwoKeys() {
        #expect(ProductRoute.routeKey != RouteFixtures.ProductRoute.routeKey)
    }

    @Test("A route key's type name drops the module")
    func routeKeyTypeNameDropsModule() {
        #expect(ProductRoute.routeKey.typeName == "ProductRoute")
        #expect(OrderRoute.routeKey.typeName == "RouteFixtures.OrderRoute")
        #expect(RouteFixtures.Box<Int>.routeKey.typeName == "RouteFixtures.Box<Swift.Int>")
        #expect(hiddenRouteKey.typeName == "HiddenRoute")
    }

    @Test("A route key encodes as a plain string")
    func routeKeyEncodesAsPlainString() throws {
        let data = try JSONEncoder().encode(ProductRoute.routeKey)

        #expect(String(decoding: data, as: UTF8.self) == "\"WaypointTestSupport.ProductRoute\"")
        #expect(try JSONDecoder().decode(RouteKey.self, from: data) == ProductRoute.routeKey)
    }

    @Test("A route saved under a former key still decodes")
    func formerRouteKeyDecodes() throws {
        let saved = Data(#"{"route":"WaypointCoreTests.OldOrderRoute","value":{"id":5}}"#.utf8)

        let route = try decoder(registering: OrderRoute.self).decode(AnyRoute.self, from: saved)

        #expect(route == AnyRoute(OrderRoute(id: 5)))
    }

    @Test("Encoding uses the current key, not a former one")
    func encodingUsesCurrentKey() throws {
        let data = try JSONEncoder().encode(AnyRoute(OrderRoute(id: 5)))
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("WaypointCoreTests.RouteFixtures.OrderRoute"))
        #expect(!json.contains("OldOrderRoute"))
    }

    @Test("A former key that is another route's key is reported as a duplicate")
    func formerKeyOfAnotherRouteReportsDuplicate() throws {
        let registry = RouteRegistry()
            .registering(OrderRoute.self)
            .registering(RouteFixtures.ClashingRoute.self)

        let key = OrderRoute.routeKey
        let clashing = RouteFixtures.ClashingRoute.routeKey.rawValue
        let types = [key.rawValue, clashing]
        let expectedProblems: [RouteDecodingError] = [.duplicateRouteKey(key, types: types)]
        #expect(registry.problems == expectedProblems)
        #expect(registry.type(for: key) == OrderRoute.self)
    }

    @Test("A private route is reported as having an unstable key")
    func privateRouteReportsUnstableKey() {
        let registry = registeringHiddenRoute(in: RouteRegistry())

        let expectedProblems: [RouteDecodingError] = [.unstableRouteKey(hiddenRouteKey)]
        #expect(registry.problems == expectedProblems)
        #expect(throws: RouteDecodingError.unstableRouteKey(hiddenRouteKey)) {
            try JSONEncoder().encode(hiddenRoute)
        }
    }

    @Test("An empty former key is reported as invalid")
    func emptyFormerKeyReportsInvalid() {
        let registry = RouteRegistry()
            .registering(RouteFixtures.EmptyFormerKeyRoute.self)

        let expectedProblems: [RouteDecodingError] = [.invalidRouteKey("")]
        #expect(registry.problems == expectedProblems)
        #expect(registry.isRegistered(RouteFixtures.EmptyFormerKeyRoute.self))
    }

    @Test("Registering a route twice does nothing more")
    func registeringTwiceDoesNothing() {
        let registry = RouteRegistry()
            .registering(OrderRoute.self)
            .registering(OrderRoute.self)

        #expect(registry.problems.isEmpty)
        #expect(registry.registeredTypes.count == 1)
    }

    @Test("The unknown key message suggests adding a former key")
    func unknownKeyMessageSuggestsFormerKey() {
        let error = RouteDecodingError.unknownRouteKey(RouteKey("Shop.OldProductRoute"))

        #expect(error.description == "unknownRouteKey key=Shop.OldProductRoute")
        let hint = #"add RouteKey("Shop.OldProductRoute") to the new type's formerRouteKeys"#
        #expect(error.debugDescription.contains(hint))
    }

    @Test("AnyRoute equality respects the route's type")
    func anyRouteEqualityRespectsType() {
        #expect(AnyRoute(OrderRoute(id: 1)) != AnyRoute(RouteFixtures.InvoiceRoute(id: 1)))
        #expect(AnyRoute(OrderRoute(id: 1)) == AnyRoute(OrderRoute(id: 1)))
        let routes: Set<AnyRoute> = [AnyRoute(OrderRoute(id: 1)), AnyRoute(OrderRoute(id: 1))]
        #expect(routes.count == 1)
    }

    @Test("AnyRoute unwraps to its original type")
    func anyRouteUnwrapsToOriginalType() {
        let route = AnyRoute(ProductRoute(id: 42))

        #expect(route.as(ProductRoute.self) == ProductRoute(id: 42))
        #expect(route.as(HomeRoute.self) == nil)
        #expect(route.is(ProductRoute.self))
        #expect(!route.is(HomeRoute.self))
        #expect(route.routeKey == ProductRoute.routeKey)
    }

    @Test("The registry decodes a registered type")
    func registryDecodesRegisteredType() throws {
        let original = [AnyRoute(PaymentRoute.card(id: 3, nickname: "Travel"))]
        let data = try JSONEncoder().encode(original)

        let decoded = try decoder(registering: PaymentRoute.self).decode([AnyRoute].self, from: data)

        #expect(decoded == original)
    }

    @Test("The registry reports an unknown key")
    func registryReportsUnknownKey() throws {
        let data = try JSONEncoder().encode(AnyRoute(ProductRoute(id: 1)))

        #expect(throws: RouteDecodingError.unknownRouteKey(ProductRoute.routeKey)) {
            try decoder(registering: OrderRoute.self).decode(AnyRoute.self, from: data)
        }
    }

    @Test("The registry reports a removed enum case as an invalid payload")
    func registryReportsRemovedCase() {
        let saved = Data(#"{"route":"WaypointCoreTests.RouteFixtures.PaymentRoute","value":{"giftCard":{}}}"#.utf8)

        #expect(throws: RouteDecodingError.invalidPayload(PaymentRoute.routeKey)) {
            try decoder(registering: PaymentRoute.self).decode(AnyRoute.self, from: saved)
        }
    }

    @Test("Decoding without a registry fails without crashing")
    func decodingWithoutRegistryFailsWithoutCrashing() throws {
        let data = try JSONEncoder().encode(AnyRoute(ProductRoute(id: 1)))

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AnyRoute.self, from: data)
        }
    }

    @Test("AnyRoute can be sent across actors")
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
