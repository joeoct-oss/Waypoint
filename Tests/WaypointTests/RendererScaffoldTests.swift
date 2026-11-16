//
//  RendererScaffoldTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
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
