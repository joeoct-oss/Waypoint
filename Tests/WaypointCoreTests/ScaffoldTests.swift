//
//  ScaffoldTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing

@testable import WaypointCore

@Test
func coreModuleIsReachable() {
    #expect(WaypointCoreInfo.version == "0.0.0")
}
