//
//  RouteTableTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointCore
import WaypointTestSupport

/// The type-keyed destination table shared by both renderers (see the Routes
/// article).
@Suite("Route table")
struct RouteTableTests {
    @Test("A route table looks up by route type")
    func routeTableLooksUpByType() {
        let table = RouteTable<String>()
            .registering(ProductRoute.self) { route in
                "product \(route.id)"
            }
            .registering(HomeRoute.self) { _ in
                "home"
            }

        #expect(table.payload(for: AnyRoute(ProductRoute(id: 7))) == "product 7")
        #expect(table.payload(for: AnyRoute(HomeRoute())) == "home")
    }

    @Test("An unregistered route has no entry")
    func unregisteredRouteHasNoPayload() {
        let table = RouteTable<String>()

        #expect(table.payload(for: AnyRoute(SettingsRoute())) == nil)
        #expect(!table.contains(SettingsRoute.self))
    }

    @Test("Registering a route again replaces its entry")
    func registeringAgainReplacesDestination() {
        let table = RouteTable<String>()
            .registering(HomeRoute.self) { _ in
                "old"
            }
            .registering(HomeRoute.self) { _ in
                "new"
            }

        #expect(table.payload(for: AnyRoute(HomeRoute())) == "new")
        #expect(table.registeredTypes.count == 1)
    }

    @Test("A route table registers its routes for decoding")
    func routeTableRegistersForDecoding() {
        let table = RouteTable<Int>()
            .registering(ProductRoute.self) { route in
                route.id
            }

        #expect(table.registry.isRegistered(ProductRoute.self))
        #expect(table.contains(ProductRoute.self))
    }
}
