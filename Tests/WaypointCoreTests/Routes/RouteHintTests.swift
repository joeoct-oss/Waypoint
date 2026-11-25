//
//  RouteHintTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing

@testable import WaypointCore

/// A hint rides along on screen only: it is never saved, compared, described or linked (see the
/// Routes article).
@Suite("Route hints")
struct RouteHintTests {
    typealias HintedProductRoute = RouteFixtures.HintedProductRoute

    typealias LoadedProduct = RouteFixtures.LoadedProduct

    /// A route for product 42 with a loaded product as its hint.
    private static let hinted = HintedProductRoute(
        id: 42,
        preview: LoadedProduct(name: "Orbit Lamp")
    )

    @Test
    func hintIsReadable() {
        #expect(Self.hinted.preview?.name == "Orbit Lamp")
        #expect(HintedProductRoute(id: 42).preview == nil)
    }

    @Test
    func hintIsNotEncoded() throws {
        let data = try JSONEncoder().encode(Self.hinted)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json == #"{"id":42}"#)
    }

    @Test
    func erasedRouteSavesWithoutTheHint() throws {
        let data = try JSONEncoder().encode(AnyRoute(Self.hinted))
        let json = String(decoding: data, as: UTF8.self)

        #expect(!json.contains("preview"))
        #expect(!json.contains("Orbit Lamp"))
    }

    @Test
    func hintDecodesToNil() throws {
        let data = try JSONEncoder().encode(Self.hinted)

        let decoded = try JSONDecoder().decode(HintedProductRoute.self, from: data)

        #expect(decoded.id == 42)
        #expect(decoded.preview == nil)
    }

    @Test
    func restoredRouteHasNoHint() throws {
        let saved = try JSONEncoder().encode(AnyRoute(Self.hinted))
        let decoder = JSONDecoder()
        decoder.userInfo[.routeRegistry] = RouteRegistry().registering(HintedProductRoute.self)

        let restored = try decoder.decode(AnyRoute.self, from: saved)

        #expect(restored.as(HintedProductRoute.self)?.preview == nil)
        #expect(restored == AnyRoute(Self.hinted))
    }

    @Test
    func routesWithSameIdAreEqualWhateverTheHint() {
        let other = HintedProductRoute(
            id: 42,
            preview: LoadedProduct(name: "Comet Mug")
        )
        let bare = HintedProductRoute(id: 42)
        let hashes: Set = [
            Self.hinted.hashValue,
            other.hashValue,
            bare.hashValue,
        ]

        #expect(Self.hinted == other)
        #expect(Self.hinted == bare)
        #expect(hashes.count == 1)
        #expect(Self.hinted != HintedProductRoute(id: 7))
    }

    @Test
    func descriptionsNeverPrintTheHint() {
        let route = AnyRoute(Self.hinted)

        #expect(route.description == "RouteFixtures.HintedProductRoute(id: 42)")
        #expect(route.debugDescription(revealingPrivateValues: true) == route.description)
        #expect(RouteDescriber.readable(Self.hinted, revealingPrivateValues: true) == "Hinted product (id: 42)")
    }

    @Test
    func aSavedHintIsDroppedOnRestore() throws {
        let saved = Data(#"{"id":42,"preview":{"name":"Orbit Lamp"}}"#.utf8)

        let route = try JSONDecoder().decode(HintedProductRoute.self, from: saved)

        #expect(route == HintedProductRoute(id: 42))
        #expect(route.preview == nil)
    }

    @Test
    func aHintOnItsOwnSavesAsNullAndRestoresEmpty() throws {
        let hint = RouteHint(wrappedValue: LoadedProduct(name: "Orbit Lamp"))

        let data = try JSONEncoder().encode(hint)
        let restored = try JSONDecoder().decode(RouteHint<LoadedProduct>.self, from: data)

        #expect(String(decoding: data, as: UTF8.self) == "null")
        #expect(restored.wrappedValue == nil)
    }

    @Test
    func linkBuiltRouteHasNoHint() throws {
        let linkValues = Data(#"{"id":42}"#.utf8)

        let route = try JSONDecoder().decode(HintedProductRoute.self, from: linkValues)

        #expect(route == HintedProductRoute(id: 42))
        #expect(route.preview == nil)
    }
}
