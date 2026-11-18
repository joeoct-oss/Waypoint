//
//  FixtureTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointTestSupport

/// Encodes and decodes a value, so the test proves the fixture is hashable, sendable and codable
/// (see the Routes article).
private func roundTrip<Value: Hashable & Sendable & Codable>(_ value: Value) throws -> Value {
    try JSONDecoder().decode(Value.self, from: JSONEncoder().encode(value))
}

@Test
func fixturesAreHashableAndSendable() throws {
    #expect(try roundTrip(HomeRoute()) == HomeRoute())
    #expect(try roundTrip(ProductRoute(id: 42)) == ProductRoute(id: 42))
    #expect(try roundTrip(SettingsRoute()) == SettingsRoute())
    #expect(try roundTrip(WizardStep.payment) == .payment)
    #expect(ProductRoute(id: 1) != ProductRoute(id: 2))
}
