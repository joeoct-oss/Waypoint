//
//  RendererScaffoldTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(UIKit)
    import Testing
    import WaypointTestSupport

    @testable import WaypointUIKit

    @Test
    func uiKitRendererModuleLinks() {
        #expect(WaypointUIKitRendererInfo.name == "UIKit")
    }
#endif
