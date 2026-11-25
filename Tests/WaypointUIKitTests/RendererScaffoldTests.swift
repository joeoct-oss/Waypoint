//
//  RendererScaffoldTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(UIKit)
    import Testing
    import WaypointTestSupport

    @testable import WaypointUIKit

    @Test("The UIKit renderer module links")
    func uiKitRendererModuleLinks() {
        #expect(WaypointUIKitRendererInfo.name == "UIKit")
    }
#endif
