//
//  StackCoordinatingTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// `StackCoordinating` and the router table: a coordinator's router is made on the first read,
/// named, registered and released with the coordinator (planning #313).
@Suite("Stack coordinators and the router table")
@MainActor
struct StackCoordinatingTests {
    @Test("A stack coordinator's router is made, active and empty, on first read")
    func routerMadeOnFirstRead() {
        let coordinator = ShopListCoordinator()

        let router = coordinator.router

        #expect(router.isActive)
        #expect(router.state.path.isEmpty)
    }

    @Test("The same coordinator always gets the same router, and another gets its own")
    func sameCoordinatorGetsSameRouter() {
        let coordinator = ShopListCoordinator()
        let other = ShopListCoordinator()

        let first = coordinator.router

        #expect(coordinator.router === first)
        #expect(other.router !== first)
    }

    @Test("A router the coordinator makes wins over the default")
    func declaredRouterWinsOverDefault() {
        let coordinator = OwnRouterCoordinator()

        let router = coordinator.router

        #expect(router.flowID == OwnRouterCoordinator.flow)
        #expect(coordinator.router === router)
    }

    @Test("A router from makeRouter gets the coordinator's routes registered")
    func ownRouterFromMakeRouterIsRegistered() {
        let coordinator = OwnRouterCoordinator()

        let outcome = coordinator.router.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
    }

    @Test("A stored router is reported, then adopted with the coordinator's routes")
    func storedRouterIsReportedAndAdopted() throws {
        let stored = StackRouter(flow: FlowID("stored"))
        let reported = Spy<NavigationIssue, Void>()
        stored.tree.onReported { issue in
            reported(issue)
        }
        let coordinator = StoredRouterCoordinator(router: stored)
        let pushBeforeTouch = coordinator.router.push(ProductRoute(id: 1))

        _ = coordinator.navigator
        _ = coordinator.navigator

        #expect(pushBeforeTouch.failure?.issue.kind == .unregisteredRoute)
        let kinds = reported.calls.map(\.kind)
        let expectedKinds: [NavigationIssue.Kind] = [.unregisteredRoute, .routerNotFromWaypoint]
        #expect(kinds == expectedKinds)
        let issue = try #require(reported.lastCall)
        #expect(issue.message.contains("StoredRouterCoordinator"))
        #expect(issue.message.contains("makeRouter()"))
        #expect(issue.message.contains("rootName"))
        #expect(stored.coordinatorName == "StoredRouterCoordinator")
        #expect(coordinator.registrations.callCount == 1)
        #expect(coordinator.router.push(ProductRoute(id: 1)) == .applied)
    }

    @Test("A stored router of another coordinator is reported and not adopted")
    func storedRouterOfAnotherCoordinatorIsNotAdopted() throws {
        let owner = ShopListCoordinator()
        let shared = owner.router
        let reported = Spy<NavigationIssue, Void>()
        shared.tree.onReported { issue in
            reported(issue)
        }
        let borrower = StoredRouterCoordinator(router: shared)

        _ = borrower.navigator
        _ = borrower.navigator

        let kinds = reported.calls.map(\.kind)
        let expectedKinds: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(kinds == expectedKinds)
        let issue = try #require(reported.lastCall)
        #expect(issue.message.contains("StoredRouterCoordinator"))
        #expect(issue.message.contains("ShopListCoordinator"))
        #expect(shared.coordinatorName == "ShopListCoordinator")
        #expect(shared.rootName == "ShopList")
        #expect(borrower.registrations.callCount == 0)
        #expect(owner.router === shared)
    }

    @Test("A router from makeRouter that another coordinator owns is reported and not adopted")
    func madeRouterOfAnotherCoordinatorIsNotAdopted() throws {
        let owner = ShopListCoordinator()
        let shared = owner.router
        let reported = Spy<NavigationIssue, Void>()
        shared.tree.onReported { issue in
            reported(issue)
        }
        let borrower = GivenRouterCoordinator(given: shared)

        let router = borrower.router
        _ = borrower.router

        let kinds = reported.calls.map(\.kind)
        let expectedKinds: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(kinds == expectedKinds)
        let issue = try #require(reported.lastCall)
        #expect(issue.message.contains("GivenRouterCoordinator makeRouter() returns"))
        #expect(!issue.message.contains("stored"))
        #expect(router === shared)
        #expect(shared.coordinatorName == "ShopListCoordinator")
    }

    @Test("A freed coordinator leaves no router behind")
    func freedCoordinatorLeavesNoRouter() {
        weak let released = makeAndDropCoordinatorRouter()

        _ = ShopListCoordinator().router

        #expect(released == nil)
    }

    @Test("A coordinator names its router after its type")
    func conformingCoordinatorNamesItsRouter() {
        let coordinator = ShopListCoordinator()

        #expect(coordinator.router.coordinatorName == "ShopListCoordinator")
    }

    @Test("The default root name comes from the coordinator's type")
    func defaultRootNameComesFromType() {
        let plain = ShopListCoordinator()
        let declared = OwnRouterCoordinator()

        #expect(plain.rootName == "ShopList")
        #expect(plain.router.rootName == "ShopList")
        #expect(declared.router.rootName == "Own list")
    }

    @Test("The default root name replaces a name makeRouter set, and that is reported")
    func defaultRootNameReplacesTheNameMakeRouterSet() throws {
        let coordinator = NamedRouterCoordinator()
        let reported = Spy<NavigationIssue, Void>()
        coordinator.made.tree.onReported { issue in
            reported(issue)
        }

        let router = coordinator.router

        #expect(router.rootName == "NamedRouter")
        let issue = try #require(reported.lastCall)
        #expect(issue.kind == .rootNameReplaced)
        #expect(issue.message.contains("\"Made list\""))
        #expect(issue.message.contains("rootName"))
    }

    @Test("A router from makeRouter ends with its coordinator and its reuse is reported")
    func routerFromMakeRouterEndsWithItsCoordinator() throws {
        let router = makeAndDropCoordinatorRouter()
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }
        let next = GivenRouterCoordinator(given: router)

        let outcome = next.router.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        let issue = try #require(reported.calls.first { $0.kind == .releasedRouterReturned })
        #expect(issue.message.contains("GivenRouterCoordinator"))
    }

    @Test("A declared root name wins over the one makeRouter set")
    func declaredRootNameWinsOverMakeRouters() {
        let coordinator = OwnRouterCoordinator()

        #expect(coordinator.router.rootName == "Own list")
    }

    @Test("The default navigator pushes on the coordinator's router")
    func defaultNavigatorUsesRouter() {
        let coordinator = OwnRouterCoordinator()

        let outcome = coordinator.navigator.push(ProductRoute(id: 2))
        let scoped = coordinator.navigator(for: ShopFlow.self)

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(ProductRoute(id: 2))]
        #expect(coordinator.router.state.path == expectedPath)
        #expect(scoped.isActive)
    }

    @Test("An inner coordinator keeps its own named router")
    func innerCoordinatorKeepsItsOwnRouter() {
        let outer = OuterCoordinator()

        #expect(outer.inner.router === outer.innerRouter)
        #expect(outer.router !== outer.innerRouter)
        #expect(outer.innerRouter.coordinatorName == "ShopListCoordinator")
        #expect(outer.router.coordinatorName == "OuterCoordinator")
    }

    @Test("Calls on a swept router are ignored")
    func sweptRouterCallsAreIgnored() {
        let router = makeAndDropCoordinatorRouter()
        let other = StackRouter(configuration: .permissive)

        other.push(ProductRoute(id: 1))

        #expect(!router.isActive)
        #expect(router.push(ProductRoute(id: 1)) == .ignored)
        #expect(router.state.path.isEmpty)
    }

    @Test("A kept navigator's first call after its coordinator is gone is ignored")
    func keptNavigatorsFirstCallAfterCoordinatorIsGoneIsIgnored() {
        let router = makeAndDropCoordinatorRouter()
        let navigation = router.navigator

        let outcome = navigation.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        #expect(router.state.path.isEmpty)
    }

    @Test("A stored router reused after its coordinator is gone is ignored and reported")
    func storedRouterReusedAfterItsCoordinatorIsGoneIsReported() throws {
        let stored = StackRouter(configuration: .permissive)
        let reported = Spy<NavigationIssue, Void>()
        stored.tree.onReported { issue in
            reported(issue)
        }
        adoptAndDrop(stored)
        let next = StoredRouterCoordinator(router: stored)

        let outcome = next.navigator.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        #expect(!stored.isActive)
        let issue = try #require(reported.calls.first { $0.kind == .releasedRouterReturned })
        #expect(issue.message.contains("StoredRouterCoordinator stores"))
    }

    @Test("A swept router takes its presented flow with it")
    func sweptRouterTakesItsPresentedFlowWithIt() throws {
        let router = makeAndDropCoordinatorRouter(presenting: true)
        let presented = try #require(router.presented)
        let navigation = presented.navigator

        let outcome = navigation.push(ProductRoute(id: 1))

        #expect(outcome == .ignored)
        #expect(!router.isActive)
        #expect(!presented.isActive)
    }

    @Test("A queued call replayed after its coordinator is gone changes nothing more")
    func queuedCallReplayedAfterCoordinatorIsGoneIsIgnored() throws {
        let holder = CoordinatorHolder()
        let router = try #require(holder.coordinator).router
        let navigation = router.navigator
        let once = Once()
        let queued = Spy<NavigationOutcome, Void>()
        router.tree.onApplied { _ in
            guard once.claim() else {
                return
            }
            queued(navigation.push(ProductRoute(id: 2)))
            holder.release()
        }

        router.push(ProductRoute(id: 1))

        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(queued.lastCall == .queued)
        #expect(router.state.path == expectedPath)
        #expect(!router.isActive)
    }

    @Test("A coordinator with a reused identity gets a fresh router")
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

    @Test("Reading the router in a coordinator's deinit gives it back inert")
    func readInDeinitOfACoordinatorWithARouterGetsItInert() throws {
        let outcomes = Spy<(NavigationOutcome, StackRouter), Void>()
        let router = makeAndDropDeinitReader(outcomes: outcomes, readsFirst: true)

        let (outcome, read) = try #require(outcomes.lastCall)
        #expect(outcome == .ignored)
        #expect(read === router)
        #expect(!router.isActive)
        #expect(router.state.path.isEmpty)
    }

    @Test("A first router read in a coordinator's deinit gives an inert router")
    func firstReadInDeinitGetsAnInertRouter() throws {
        let outcomes = Spy<(NavigationOutcome, StackRouter), Void>()
        _ = makeAndDropDeinitReader(outcomes: outcomes, readsFirst: false)

        let (outcome, read) = try #require(outcomes.lastCall)
        #expect(outcome == .ignored)
        #expect(!read.isActive)
    }

    @Test("A first read in deinit leaves a router still in use working")
    func firstReadInDeinitKeepsARouterStillInUseLive() throws {
        let owner = ShopListCoordinator()
        let live = owner.router
        let outcomes = Spy<(NavigationOutcome, StackRouter), Void>()
        _ = makeAndDropDeinitReader(outcomes: outcomes, readsFirst: false, madeRouter: live)

        let (outcome, read) = try #require(outcomes.lastCall)
        #expect(outcome == .ignored)
        #expect(read !== live)
        #expect(live.isActive)
        #expect(live.state.path.isEmpty)
    }

    @Test("A coordinator released during a sweep gets an inert router and nothing crashes")
    func coordinatorDeinitDuringSweepDoesNotCrash() throws {
        let outcomes = Spy<(NavigationOutcome, StackRouter), Void>()
        keepDeinitReaderInFreedCoordinatorsTree(outcomes: outcomes)

        _ = ShopListCoordinator().router

        let (outcome, read) = try #require(outcomes.lastCall)
        #expect(outcome == .ignored)
        #expect(!read.isActive)
    }

    /// Makes a coordinator whose router's tree is the only holder of a coordinator that reads
    /// its router in `deinit`, then drops the first one. The sweep that lets that router go
    /// frees the second coordinator, whose `deinit` reads the table.
    private func keepDeinitReaderInFreedCoordinatorsTree(
        outcomes: Spy<(NavigationOutcome, StackRouter), Void>
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
        outcomes: Spy<(NavigationOutcome, StackRouter), Void>,
        readsFirst: Bool,
        madeRouter: StackRouter? = nil
    ) -> StackRouter {
        let coordinator = DeinitReadingCoordinator(outcomes: outcomes, madeRouter: madeRouter)
        return readsFirst ? coordinator.router : StackRouter()
    }

    @Test("A coordinator drawn twice at once is reported")
    func coordinatorDrawnTwiceIsReported() throws {
        let coordinator = ShopListCoordinator()
        let router = coordinator.router
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }

        router.rendererDidStartDrawing(coordinator)
        router.rendererCheckDrawing(coordinator)
        let drawnOnce = reported.calls.isEmpty
        router.rendererDidStartDrawing(coordinator)
        router.rendererCheckDrawing(coordinator)

        #expect(drawnOnce)
        let kinds = reported.calls.map(\.kind)
        let expectedKinds: [NavigationIssue.Kind] = [.coordinatorDrawnTwice]
        #expect(kinds == expectedKinds)
        let issue = try #require(reported.lastCall)
        #expect(issue.message.contains("ShopListCoordinator.view"))
    }

    @Test("A view replaced in one update is not reported")
    func viewReplacedInOneUpdateIsNotReported() {
        let coordinator = ShopListCoordinator()
        let router = coordinator.router
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }

        router.rendererDidStartDrawing(coordinator)
        router.rendererDidStartDrawing(coordinator)
        router.rendererDidStopDrawing(coordinator)
        router.rendererCheckDrawing(coordinator)

        #expect(reported.calls.isEmpty)
    }

    @Test("Coordinators sharing one stack are not reported")
    func coordinatorsSharingOneStackAreNotReported() {
        let first = ShopListCoordinator()
        let second = ShopListCoordinator()
        let router = first.router
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }

        router.rendererDidStartDrawing(first)
        router.rendererDidStartDrawing(second)
        router.rendererCheckDrawing(first)
        router.rendererCheckDrawing(second)

        #expect(reported.calls.isEmpty)
    }
}
