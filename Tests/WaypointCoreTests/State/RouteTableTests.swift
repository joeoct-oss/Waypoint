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

/// The type-keyed destination table shared by both renderers (#45, see the Routes article).
@Suite("Route table")
struct RouteTableTests {
    @Test
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

    @Test
    func unregisteredRouteHasNoPayload() {
        let table = RouteTable<String>()

        #expect(table.payload(for: AnyRoute(SettingsRoute())) == nil)
        #expect(!table.contains(SettingsRoute.self))
    }

    @Test
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

    @Test
    func routeTableRegistersForDecoding() {
        let table = RouteTable<Int>()
            .registering(ProductRoute.self) { route in
                route.id
            }

        #expect(table.registry.isRegistered(ProductRoute.self))
        #expect(table.contains(ProductRoute.self))
    }
}
