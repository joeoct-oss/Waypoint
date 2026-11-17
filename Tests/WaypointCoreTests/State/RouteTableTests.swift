//
//  RouteTableTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointCore
import WaypointTestSupport

/// The type-keyed destination table shared by both renderers (#45, decision 0003).
@Suite("Route table")
struct RouteTableTests {
    @Test
    func routeTableLooksUpByType() {
        var table = RouteTable<String>()
        table.register(ProductRoute.self) { route in
            "product \(route.id)"
        }
        table.register(HomeRoute.self) { _ in
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
        var table = RouteTable<String>()
        table.register(HomeRoute.self) { _ in
            "old"
        }
        table.register(HomeRoute.self) { _ in
            "new"
        }

        #expect(table.payload(for: AnyRoute(HomeRoute())) == "new")
        #expect(table.registeredTypes.count == 1)
    }

    @Test
    func routeTableRegistersForDecoding() {
        var table = RouteTable<Int>()
        table.register(ProductRoute.self) { route in
            route.id
        }

        #expect(table.registry.isRegistered(ProductRoute.self))
        #expect(table.contains(ProductRoute.self))
    }
}
