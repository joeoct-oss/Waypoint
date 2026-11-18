//
//  RendererScaffoldTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import Testing
    import WaypointTestSupport

    @testable import Waypoint

    @Test
    func swiftUIRendererModuleLinks() {
        #expect(WaypointRendererInfo.name == "SwiftUI")
    }
#endif
