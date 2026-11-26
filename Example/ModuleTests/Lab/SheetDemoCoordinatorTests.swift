//
//  SheetDemoCoordinatorTests.swift
//  ExampleLabTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleLab
import Testing
import WaypointCore

// The Lab's Sheet story stores no router: Waypoint makes it from the Lab's
// configuration the first time it is read, names it after the story's coordinator and roots it at
// the story's screen.
struct SheetDemoCoordinatorTests {
    private static let flowID = FlowID("labSheet")

    @Test("The router is made for the sheet story")
    func routerIsMadeForTheSheetStory() {
        let demo = TestLab.makeFactory().makeSheetDemo(onClose: { })

        let router = demo.router

        #expect(router.flowID == Self.flowID)
        #expect(router.coordinatorName == "SheetDemoCoordinator")
        #expect(router.rootName == "Sheet story")
        #expect(demo.router === router)
    }
}
