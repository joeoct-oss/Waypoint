//
//  DetailPushCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Waypoint
@testable import WaypointExample

// The Lab's Detail push coordinator stores no router (#59): Waypoint makes it from the Lab's
// configuration the first time it is read, names it after the coordinator, and makes it inert
// once the Lab lets the demo go, so a navigator kept past the demo changes nothing.
struct DetailPushCoordinatorTests {
    private static let flowID = FlowID("detailPush")

    @Test
    func routerIsMadeForTheDetailPushFlow() {
        let coordinator = DetailPushCoordinator(navigation: .default)

        let router = coordinator.router

        #expect(router.flowID == Self.flowID)
        #expect(router.coordinatorName == "DetailPushCoordinator")
        #expect(router.rootName == MainTab.shop.title)
        #expect(coordinator.router === router)
    }

    @Test
    func closedDemoLeavesNoLiveRouter() throws {
        let lab = LabDemoCoordinator(navigation: .default)
        lab.showDemo(.detailPush)
        let router = try #require(lab.detailPush).router
        let navigation = router.navigator

        lab.releaseDemo()

        #expect(navigation.push(DetailProductRoute(productID: 1)) == .ignored)
        #expect(!router.isActive)
    }
}
