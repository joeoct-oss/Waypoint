//
//  TabsDemoCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Waypoint
@testable import WaypointExample

// The Lab's Tabs coordinator stores no router (planning #313): Waypoint makes it the first time it
// is read and asks for each tab's coordinator, whose router becomes the tab's stack. Tabs added
// later get their coordinators, and removed tabs' stacks leave the tree.
struct TabsDemoCoordinatorTests {
    @Test
    func eachTabStackIsItsCoordinatorsRouter() {
        let demo = TestLab.makeFactory().makeTabsDemo(onClose: { })

        let router = demo.router

        #expect(router.flowID == FlowID("labTabs"))
        #expect(router.coordinatorName == "TabsDemoCoordinator")
        for tab in router.state.tabs {
            let stack = router.router(for: tab)
            #expect(stack.isActive)
            #expect(stack.coordinatorName == "TabsDemoTabCoordinator")
            #expect(stack.flowID == FlowID(tab.rawValue))
        }
    }

    @Test
    func addedTabsGetTheirCoordinatorsAndRemovedTabsLeave() {
        let demo = TestLab.makeFactory().makeTabsDemo(onClose: { })
        demo.toggleTabs()
        let cart = demo.router.router(for: .cart)

        demo.toggleTabs()

        #expect(cart.coordinatorName == "TabsDemoTabCoordinator")
        #expect(!cart.isActive)
        #expect(demo.router.router(for: .shop).isActive)
    }
}
