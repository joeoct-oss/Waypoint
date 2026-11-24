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

// The Lab's Detail push coordinator stores no router (planning #313): Waypoint makes it from the
// Lab's configuration the first time it is read, names it after the coordinator, and makes it inert
// once the Lab lets the demo go, so a navigator kept past the demo changes nothing.
struct DetailPushCoordinatorTests {
    private static let flowID = FlowID("detailPush")

    @Test
    func routerIsMadeForTheDetailPushFlow() {
        let coordinator = DetailPushCoordinator(
            navigation: .default,
            onClose: { }
        )

        let router = coordinator.router

        #expect(router.flowID == Self.flowID)
        #expect(router.coordinatorName == "DetailPushCoordinator")
        #expect(router.rootName == MainTab.shop.title)
        #expect(coordinator.router === router)
    }

    // Its `destinations` are registered when the router is made, with no `register` call, so a
    // push before the stack is drawn is applied.
    @Test
    func destinationsRegisteredWithoutRegisterCalls() {
        let coordinator = DetailPushCoordinator(
            navigation: .default,
            onClose: { }
        )

        let outcome = coordinator.router.push(DetailProductRoute(productID: 1))

        #expect(outcome == .applied)
        #expect(coordinator.router.registry.isRegistered(DetailProductRoute.self))
        #expect(coordinator.router.registry.isRegistered(DetailCartRoute.self))
        let declared = coordinator.router.declaredFlow.map(ObjectIdentifier.init)
        #expect(declared == ObjectIdentifier(DetailPushFlow.self))
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
