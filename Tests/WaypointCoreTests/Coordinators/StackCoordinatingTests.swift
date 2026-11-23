//
//  StackCoordinatingTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// `StackCoordinating` and the router table: a coordinator's router is made on the first read,
/// named, registered and released with the coordinator (#59).
@Suite("Stack coordinators and the router table")
@MainActor
struct StackCoordinatingTests {
    @Test
    func routerMadeOnFirstRead() {
        let coordinator = ShopListCoordinator()

        let router = coordinator.router

        #expect(router.isActive)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func sameCoordinatorGetsSameRouter() {
        let coordinator = ShopListCoordinator()
        let other = ShopListCoordinator()

        let first = coordinator.router

        #expect(coordinator.router === first)
        #expect(other.router !== first)
    }

    @Test
    func declaredRouterWinsOverDefault() {
        let coordinator = OwnRouterCoordinator()

        let router = coordinator.router

        #expect(router.flowID == OwnRouterCoordinator.flow)
        #expect(coordinator.router === router)
    }

    @Test
    func ownRouterFromMakeRouterIsRegistered() {
        let coordinator = OwnRouterCoordinator()

        let outcome = coordinator.router.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
    }

    @Test
    func storedRouterIsReportedAndAdopted() throws {
        let stored = StackRouter(flow: FlowID("stored"))
        let reported = Recorder<NavigationIssue>()
        stored.tree.onReported { issue in
            reported.record(issue)
        }
        let coordinator = StoredRouterCoordinator(router: stored)
        let pushBeforeTouch = coordinator.router.push(ProductRoute(id: 1))

        _ = coordinator.navigator
        _ = coordinator.navigator

        #expect(pushBeforeTouch.failure?.issue.kind == .unregisteredRoute)
        let kinds = reported.values.map(\.kind)
        let expectedKinds: [NavigationIssue.Kind] = [.unregisteredRoute, .routerNotFromWaypoint]
        #expect(kinds == expectedKinds)
        let issue = try #require(reported.last)
        #expect(issue.message.contains("StoredRouterCoordinator"))
        #expect(issue.message.contains("makeRouter()"))
        #expect(issue.message.contains("rootName"))
        #expect(stored.coordinatorName == "StoredRouterCoordinator")
        #expect(coordinator.registrations.count == 1)
        #expect(coordinator.router.push(ProductRoute(id: 1)) == .applied)
    }

    @Test
    func storedRouterOfAnotherCoordinatorIsNotAdopted() throws {
        let owner = ShopListCoordinator()
        let shared = owner.router
        let reported = Recorder<NavigationIssue>()
        shared.tree.onReported { issue in
            reported.record(issue)
        }
        let borrower = StoredRouterCoordinator(router: shared)

        _ = borrower.navigator
        _ = borrower.navigator

        let kinds = reported.values.map(\.kind)
        let expectedKinds: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(kinds == expectedKinds)
        let issue = try #require(reported.last)
        #expect(issue.message.contains("StoredRouterCoordinator"))
        #expect(issue.message.contains("ShopListCoordinator"))
        #expect(shared.coordinatorName == "ShopListCoordinator")
        #expect(shared.rootName == "ShopList")
        #expect(borrower.registrations.count == 0)
        #expect(owner.router === shared)
    }

    @Test
    func madeRouterOfAnotherCoordinatorIsNotAdopted() throws {
        let owner = ShopListCoordinator()
        let shared = owner.router
        let reported = Recorder<NavigationIssue>()
        shared.tree.onReported { issue in
            reported.record(issue)
        }
        let borrower = GivenRouterCoordinator(given: shared)

        let router = borrower.router
        _ = borrower.router

        let kinds = reported.values.map(\.kind)
        let expectedKinds: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(kinds == expectedKinds)
        let issue = try #require(reported.last)
        #expect(issue.message.contains("GivenRouterCoordinator makeRouter() returns"))
        #expect(!issue.message.contains("stored"))
        #expect(router === shared)
        #expect(shared.coordinatorName == "ShopListCoordinator")
    }

    @Test
    func freedCoordinatorLeavesNoRouter() {
        weak let released = makeAndDropCoordinatorRouter()

        _ = ShopListCoordinator().router

        #expect(released == nil)
    }

    @Test
    func conformingCoordinatorNamesItsRouter() {
        let coordinator = ShopListCoordinator()

        #expect(coordinator.router.coordinatorName == "ShopListCoordinator")
    }

    @Test
    func defaultRootNameComesFromType() {
        let plain = ShopListCoordinator()
        let declared = OwnRouterCoordinator()

        #expect(plain.rootName == "ShopList")
        #expect(plain.router.rootName == "ShopList")
        #expect(declared.router.rootName == "Own list")
    }

    @Test
    func defaultRootNameReplacesTheNameMakeRouterSet() throws {
        let coordinator = NamedRouterCoordinator()
        let reported = Recorder<NavigationIssue>()
        coordinator.made.tree.onReported { issue in
            reported.record(issue)
        }

        let router = coordinator.router

        #expect(router.rootName == "NamedRouter")
        let issue = try #require(reported.last)
        #expect(issue.kind == .rootNameReplaced)
        #expect(issue.message.contains("\"Made list\""))
        #expect(issue.message.contains("rootName"))
    }

    @Test
    func routerFromMakeRouterEndsWithItsCoordinator() throws {
        let router = makeAndDropCoordinatorRouter()
        let reported = Recorder<NavigationIssue>()
        router.tree.onReported { issue in
            reported.record(issue)
        }
        let next = GivenRouterCoordinator(given: router)

        let outcome = next.router.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        let issue = try #require(reported.values.first { $0.kind == .releasedRouterReturned })
        #expect(issue.message.contains("GivenRouterCoordinator"))
    }

    @Test
    func declaredRootNameWinsOverMakeRouters() {
        let coordinator = OwnRouterCoordinator()

        #expect(coordinator.router.rootName == "Own list")
    }

    @Test
    func defaultNavigatorUsesRouter() {
        let coordinator = OwnRouterCoordinator()

        let outcome = coordinator.navigator.push(ProductRoute(id: 2))
        let scoped = coordinator.navigator(for: ShopFlow.self)

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(ProductRoute(id: 2))]
        #expect(coordinator.router.state.path == expectedPath)
        #expect(scoped.isActive)
    }

    @Test
    func innerCoordinatorKeepsItsOwnRouter() {
        let outer = OuterCoordinator()

        #expect(outer.inner.router === outer.innerRouter)
        #expect(outer.router !== outer.innerRouter)
        #expect(outer.innerRouter.coordinatorName == "ShopListCoordinator")
        #expect(outer.router.coordinatorName == "OuterCoordinator")
    }

    @Test
    func sweptRouterCallsAreIgnored() {
        let router = makeAndDropCoordinatorRouter()
        let other = StackRouter(configuration: .permissive)

        other.push(ProductRoute(id: 1))

        #expect(!router.isActive)
        #expect(router.push(ProductRoute(id: 1)) == .ignored)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func keptNavigatorsFirstCallAfterCoordinatorIsGoneIsIgnored() {
        let router = makeAndDropCoordinatorRouter()
        let navigation = router.navigator

        let outcome = navigation.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func storedRouterReusedAfterItsCoordinatorIsGoneIsReported() throws {
        let stored = StackRouter(configuration: .permissive)
        let reported = Recorder<NavigationIssue>()
        stored.tree.onReported { issue in
            reported.record(issue)
        }
        adoptAndDrop(stored)
        let next = StoredRouterCoordinator(router: stored)

        let outcome = next.navigator.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        #expect(!stored.isActive)
        let issue = try #require(reported.values.first { $0.kind == .releasedRouterReturned })
        #expect(issue.message.contains("StoredRouterCoordinator stores"))
    }

    @Test
    func sweptRouterTakesItsPresentedFlowWithIt() throws {
        let router = makeAndDropCoordinatorRouter(presenting: true)
        let presented = try #require(router.presented)
        let navigation = presented.navigator

        let outcome = navigation.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        #expect(!router.isActive)
        #expect(!presented.isActive)
    }

    @Test
    func queuedCallReplayedAfterCoordinatorIsGoneIsIgnored() throws {
        let holder = CoordinatorHolder()
        let router = try #require(holder.coordinator).router
        let navigation = router.navigator
        let once = Once()
        let queued = Recorder<NavigationOutcome>()
        router.tree.onApplied { _ in
            guard once.claim() else {
                return
            }
            queued.record(navigation.push(ProductRoute(id: 2)))
            holder.release()
        }

        router.push(ProductRoute(id: 1))

        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(queued.last == .queued)
        #expect(router.state.path == expectedPath)
        #expect(!router.isActive)
    }

    @Test
    func reusedIdentifierGetsAFreshEntry() throws {
        let table = RouterTable()
        let freedID = try #require(makeAndDropEntry(in: table))
        let oldRouter = try #require(table.entryRouter(for: freedID))
        let newcomer = ShopListCoordinator()

        let router = table.router(of: newcomer, identifiedAs: freedID)

        #expect(router !== oldRouter)
        #expect(router.isActive)
        #expect(!oldRouter.isActive)
        #expect(table.router(of: newcomer, identifiedAs: freedID) === router)
    }

    @Test
    func readInDeinitOfACoordinatorWithARouterGetsItInert() throws {
        let outcomes = Recorder<(NavigationOutcome, StackRouter)>()
        let router = makeAndDropDeinitReader(outcomes: outcomes, readsFirst: true)

        let (outcome, read) = try #require(outcomes.last)
        #expect(outcome == .ignored)
        #expect(read === router)
        #expect(!router.isActive)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func firstReadInDeinitGetsAnInertRouter() throws {
        let outcomes = Recorder<(NavigationOutcome, StackRouter)>()
        _ = makeAndDropDeinitReader(outcomes: outcomes, readsFirst: false)

        let (outcome, read) = try #require(outcomes.last)
        #expect(outcome == .ignored)
        #expect(!read.isActive)
    }

    @Test
    func firstReadInDeinitKeepsARouterStillInUseLive() throws {
        let owner = ShopListCoordinator()
        let live = owner.router
        let outcomes = Recorder<(NavigationOutcome, StackRouter)>()
        _ = makeAndDropDeinitReader(outcomes: outcomes, readsFirst: false, madeRouter: live)

        let (outcome, read) = try #require(outcomes.last)
        #expect(outcome == .ignored)
        #expect(read !== live)
        #expect(live.isActive)
        #expect(live.state.path.isEmpty)
    }

    @Test
    func coordinatorDeinitDuringSweepDoesNotCrash() throws {
        let outcomes = Recorder<(NavigationOutcome, StackRouter)>()
        keepDeinitReaderInFreedCoordinatorsTree(outcomes: outcomes)

        _ = ShopListCoordinator().router

        let (outcome, read) = try #require(outcomes.last)
        #expect(outcome == .ignored)
        #expect(!read.isActive)
    }

    /// Makes a coordinator whose router's tree is the only holder of a coordinator that reads
    /// its router in `deinit`, then drops the first one. The sweep that lets that router go
    /// frees the second coordinator, whose `deinit` reads the table.
    private func keepDeinitReaderInFreedCoordinatorsTree(
        outcomes: Recorder<(NavigationOutcome, StackRouter)>
    ) {
        let owner = ShopListCoordinator()
        let reader = DeinitReadingCoordinator(outcomes: outcomes)
        owner.router.tree.onReported { _ in
            _ = reader
        }
    }

    /// Makes a coordinator that stores `router`, lets Waypoint adopt it, and drops the
    /// coordinator.
    private func adoptAndDrop(_ router: StackRouter) {
        _ = StoredRouterCoordinator(router: router).navigator
    }

    /// Makes a coordinator, reads its router, presents a flow on it when `presenting`, and drops
    /// the coordinator, keeping the router.
    private func makeAndDropCoordinatorRouter(presenting: Bool = false) -> StackRouter {
        let coordinator = PermissiveCoordinator()
        if presenting {
            coordinator.router.present(CartRoute())
        }
        return coordinator.router
    }

    /// Makes an entry in `table` for a coordinator that is then freed, and returns its id.
    private func makeAndDropEntry(in table: RouterTable) -> ObjectIdentifier? {
        let coordinator = ShopListCoordinator()
        _ = table.router(of: coordinator, identifiedAs: ObjectIdentifier(coordinator))
        return ObjectIdentifier(coordinator)
    }

    /// Makes a coordinator that pushes in `deinit`, reading its router first when `readsFirst`,
    /// and drops it. Returns the router it read first, or a new one.
    private func makeAndDropDeinitReader(
        outcomes: Recorder<(NavigationOutcome, StackRouter)>,
        readsFirst: Bool,
        madeRouter: StackRouter? = nil
    ) -> StackRouter {
        let coordinator = DeinitReadingCoordinator(outcomes: outcomes, madeRouter: madeRouter)
        return readsFirst ? coordinator.router : StackRouter()
    }
}
