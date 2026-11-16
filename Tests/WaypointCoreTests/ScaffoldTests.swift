//
//  ScaffoldTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing

@testable import WaypointCore

@Test
func coreModuleIsReachable() {
    #expect(WaypointCoreInfo.version == "0.0.0")
}
