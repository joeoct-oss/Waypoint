//
//  TabCoordinatingTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// `TabCoordinating`: each tab's child coordinator's router becomes its tab's stack, adopted with
/// its screens, merged into a shared stack, or refused (planning #313).
@Suite("Tab coordinators and their children")
@MainActor
struct TabCoordinatingTests {
    /// Both tab layouts, for tests that cover each.
    nonisolated static let bothLayouts: [TabStacks] = [.perTab, .shared]

    // MARK: - Children and their routers

    @Test
    func routerKindFollowsProtocol() {
        let tabs = MainTabsCoordinator()
        let stack = ShopListCoordinator()

        let tabRouter: any NavigationRouter = tabs.router
        let stackRouter: any NavigationRouter = stack.router

        #expect(tabRouter is TabRouter<MainTab>)
        #expect(stackRouter is StackRouter)
    }

    @Test
    func tabCoordinatorJoinsOnFirstRouterRead() {
        let tabs = MainTabsCoordinator()
        let askedBeforeRead = tabs.asked.values

        _ = tabs.router
        _ = tabs.router

        #expect(askedBeforeRead.isEmpty)
        #expect(tabs.asked.values == MainTab.allCases)
    }

    @Test
    func tabCoordinatorHandsChildrenTheirRouters() throws {
        let children = Recorder<(MainTab, any StackCoordinating)>()
        let tabs = MainTabsCoordinator { tab, _ in
            let child = TabChildCoordinator()
            children.record((tab, child))
            return child
        }

        let router = tabs.router

        #expect(children.count == MainTab.allCases.count)
        for (tab, child) in children.values {
            #expect(router.router(for: tab) === child.router)
            #expect(child.router.isActive)
            #expect(child.router.parent === router)
        }
        let home = try #require(children.values.first)
        #expect(home.1.router.push(ProductRoute(id: 1)) == .applied)
        #expect(router.router(for: .home).state.path.count == 1)
    }

    @Test
    func tabCoordinatorNamesEachTabRouter() {
        let tabs = MainTabsCoordinator()

        let router = tabs.router

        #expect(router.coordinatorName == "MainTabsCoordinator")
        for tab in MainTab.allCases {
            #expect(router.router(for: tab).coordinatorName == "TabChildCoordinator")
            #expect(router.router(for: tab).flowID.name == tab.rawValue)
        }
    }

    @Test
    func defaultRootNameComesFromTab() {
        let tabs = MainTabsCoordinator(giving: .shop) {
            NamedTabChildCoordinator()
        }

        let router = tabs.router

        #expect(router.router(for: .home).rootName == nil)
        #expect(router.router(for: .shop).rootName == "Deals")
    }

    @Test
    func tabChildPushInInitKeepsItsRouter() {
        let child = Recorder<EarlyPushCoordinator>()
        let tabs = MainTabsCoordinator { tab, _ in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            let early = EarlyPushCoordinator()
            child.record(early)
            return early
        }

        let stack = tabs.router.router(for: .shop)

        #expect(stack === child.last?.made)
        #expect(stack.state.path.count == 1)
        #expect(stack.parent === tabs.router)
        #expect(stack.push(ProductRoute(id: 2)) == .applied)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test
    func tabChildOwnMakeRouterBecomesTabStack() {
        let tabs = MainTabsCoordinator(giving: .shop) {
            OwnRouterCoordinator()
        }

        let stack = tabs.router.router(for: .shop)

        #expect(stack.rootName == "Own list")
        #expect(stack.flowID.name == "shop")
        #expect(stack.registry.isRegistered(ProductRoute.self))
        #expect(tabs.router.registry.isRegistered(ProductRoute.self))
    }

    @Test
    func tabNavigatorBuiltBeforeChildAdoptionForwards() throws {
        let child = Recorder<ParentReadingCoordinator>()
        let tabs = MainTabsCoordinator { tab, parent in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            child.record(reader)
            return reader
        }
        let router = tabs.router
        let reader = try #require(child.last)

        let outcome = reader.tabNavigator.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
        #expect(router.router(for: .shop) === reader.router)
        #expect(reader.router.state.path.count == 1)
    }

    @Test
    func tabPushBeforeChildAdoptionIsKept() throws {
        let child = Recorder<ParentReadingCoordinator>()
        let tabs = MainTabsCoordinator { tab, parent in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            reader.tabNavigator.push(ProductRoute(id: 1))
            child.record(reader)
            return reader
        }

        let stack = tabs.router.router(for: .shop)

        let reader = try #require(child.last)
        #expect(stack.state.path.count == 1)
        #expect(reader.router === stack)
        #expect(stack.coordinatorName == "ParentReadingCoordinator")
        #expect(reader.router.push(ProductRoute(id: 2)) == .applied)
        #expect(stack.state.path.count == 2)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test
    func tabPushFromChildOfAddedTabIsKept() throws {
        let child = Recorder<ParentReadingCoordinator>()
        let tabs = MainTabsCoordinator(tabs: MainTab.homeAndShop) { tab, parent in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            child.record(reader)
            reader.tabNavigator.push(ProductRoute(id: 1))
            return reader
        }
        let router = tabs.router

        router.setTabs(MainTab.allCases)

        let reader = try #require(child.last)
        let stack = router.router(for: .profile)
        #expect(stack.state.path.count == 1)
        #expect(reader.router === stack)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test
    func tabChildReadingParentRouterInInitDoesNotRejoin() throws {
        let child = Recorder<ParentReadingCoordinator>()
        let tabs = MainTabsCoordinator { tab, parent in
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            child.record(reader)
            return reader
        }

        let router = tabs.router

        #expect(tabs.asked.values == MainTab.allCases)
        let reader = try #require(child.values.first)
        #expect(reader.parentRouter === router)
        #expect(tabs.router === router)
    }

    @Test
    func innerTabCoordinatorsKeepTheirOwnRouters() {
        let first = MainTabsCoordinator()
        let second = MainTabsCoordinator()

        #expect(first.router !== second.router)
        #expect(first.router.router(for: .home) !== second.router.router(for: .home))
    }

    // MARK: - Adding and removing tabs

    @Test
    func tabAddedLaterGetsItsChild() {
        let tabs = MainTabsCoordinator(tabs: MainTab.homeAndShop)
        let router = tabs.router

        router.setTabs(MainTab.allCases)

        #expect(tabs.asked.values == MainTab.allCases)
        let profile = router.router(for: .profile)
        #expect(profile.isActive)
        #expect(profile.coordinatorName == "TabChildCoordinator")
        #expect(profile.push(ProductRoute(id: 1)) == .applied)
    }

    @Test
    func keptChildReturnedForATabAddedBackGetsTheNewStack() {
        let kept = TabChildCoordinator()
        let tabs = MainTabsCoordinator(giving: .profile) {
            kept
        }
        let router = tabs.router
        let oldStack = kept.router
        router.setTabs(MainTab.homeAndShop)

        router.setTabs(MainTab.allCases)

        let stack = router.router(for: .profile)
        #expect(!oldStack.isActive)
        #expect(kept.router === stack)
        #expect(stack.isActive)
        #expect(stack.coordinatorName == "TabChildCoordinator")
        #expect(kept.navigator.push(ProductRoute(id: 1)) == .applied)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test(arguments: Self.bothLayouts)
    func keptMergedChildReturnedForATabAddedBackGetsTheNewStack(stacks: TabStacks) throws {
        let kept = Recorder<ParentReadingCoordinator>()
        let tabs = MainTabsCoordinator(stacks: stacks) { tab, parent in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            if let child = kept.last {
                return child
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            reader.tabNavigator.push(ProductRoute(id: 1))
            kept.record(reader)
            return reader
        }
        let router = tabs.router
        let withoutShop: [MainTab] = [.home, .profile]
        router.setTabs(withoutShop)

        router.setTabs(MainTab.allCases)
        router.select(.shop)

        let child = try #require(kept.last)
        let stack = router.router(for: .shop)
        #expect(child.router === stack)
        #expect(stack.isActive)
        #expect(stack.coordinatorName == "ParentReadingCoordinator")
        #expect(child.navigator.push(ProductRoute(id: 2)) == .applied)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test(arguments: Self.bothLayouts)
    func removedTabReleasesItsChild(stacks: TabStacks) {
        let tabs = MainTabsCoordinator(stacks: stacks)
        weak let released = child(of: tabs, for: .profile)

        tabs.router.setTabs(MainTab.homeAndShop)

        #expect(released == nil)
        #expect(tabs.router.router(for: .home).push(ProductRoute(id: 1)) == .applied)
    }

    @Test
    func tabChildrenReleasedWithTabs() {
        weak let released = makeAndDropTabCoordinatorChild()

        RouterTable.shared.sweep()

        #expect(released == nil)
    }

    @Test
    func sweepKeepsTabRoutersLive() {
        let tabs = MainTabsCoordinator()
        let router = tabs.router
        _ = makeAndDropTabCoordinatorChild()

        RouterTable.shared.sweep()

        #expect(router.isActive)
        for tab in MainTab.allCases {
            #expect(router.router(for: tab).isActive)
            #expect(router.router(for: tab).push(ProductRoute(id: 1)) == .applied)
        }
    }

    @Test
    func childDeinitDuringSetTabsDoesNotCrash() throws {
        let outcomes = Recorder<(NavigationOutcome, StackRouter)>()
        let tabs = MainTabsCoordinator(giving: .profile) {
            DeinitReadingCoordinator(outcomes: outcomes)
        }
        let profile = tabs.router.router(for: .profile)

        tabs.router.setTabs(MainTab.homeAndShop)

        let (outcome, read) = try #require(outcomes.last)
        #expect(outcome == .ignored)
        #expect(!read.isActive)
        #expect(!profile.isActive)
        #expect(tabs.router.router(for: .home).isActive)
    }

    // MARK: - Shared stack

    @Test
    func sharedStackAsksSelectedTabFirst() {
        let tabs = MainTabsCoordinator(selection: .shop, stacks: .shared)

        _ = tabs.router

        let expected: [MainTab] = [.shop, .home, .profile]
        #expect(tabs.asked.values == expected)
    }

    @Test
    func sharedStackMergesLaterChildRouter() throws {
        let children = Recorder<any StackCoordinating>()
        let tabs = MainTabsCoordinator(stacks: .shared) { _, _ in
            let child = TabChildCoordinator()
            children.record(child)
            return child
        }

        let shared = tabs.router.router(for: .home)

        #expect(children.count == MainTab.allCases.count)
        for child in children.values {
            #expect(child.router === shared)
        }
        let later = try #require(children.last)
        #expect(later.router.push(ProductRoute(id: 1)) == .applied)
        #expect(shared.state.path.count == 1)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test
    func unselectedTabChildEarlyScreensAreDropped() throws {
        let early = Recorder<EarlyPushCoordinator>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPushCoordinator()
            early.record(child)
            return child
        }

        let shared = tabs.router.router(for: .home)

        #expect(shared.state.path.isEmpty)
        let expected: [NavigationIssue.Kind] = [.tabChildRouterMerged]
        #expect(tabs.reportedKinds == expected)
        let issue = try #require(tabs.reported.last)
        #expect(issue.message.contains("EarlyPushCoordinator"))
        #expect(issue.message.contains("profile"))
        #expect(early.last?.router === shared)
    }

    @Test
    func transactionOnMergedChildRouterForwards() throws {
        let early = Recorder<EarlyPushCoordinator>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPushCoordinator()
            early.record(child)
            return child
        }
        let shared = tabs.router.router(for: .home)
        let child = try #require(early.last)

        let outcome = child.made.transaction { transaction in
            transaction.push(ProductRoute(id: 2))
            transaction.push(ProductRoute(id: 3))
        }

        #expect(outcome == .applied)
        #expect(shared.state.path.count == 2)
    }

    @Test
    func mergedChildsEarlyPresentedFlowLeavesTheTree() throws {
        let early = Recorder<EarlyPresentCoordinator>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPresentCoordinator()
            early.record(child)
            return child
        }
        _ = tabs.router
        let child = try #require(early.last)
        let presented = try #require(child.presentedFlow)

        let outcome = presented.push(ProductRoute(id: 1))

        #expect(!presented.isActive)
        #expect(outcome == .ignored)
        let expected: [NavigationIssue.Kind] = [.tabChildRouterMerged]
        #expect(tabs.reportedKinds == expected)
    }

    @Test
    func staleNavigatorOfMergedChildForwards() throws {
        let early = Recorder<EarlyPushCoordinator>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPushCoordinator()
            early.record(child)
            return child
        }
        let shared = tabs.router.router(for: .home)
        let child = try #require(early.last)

        let outcome = child.rootNavigator.push(ProductRoute(id: 2))

        #expect(outcome == .applied)
        #expect(shared.state.path.count == 1)
        #expect(child.made.state.path.count == 1)
    }

    @Test
    func mergedStoredRouterIsNotReadopted() throws {
        let stored = Recorder<StoredRouterCoordinator>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = StoredRouterCoordinator(router: StackRouter())
            stored.record(child)
            return child
        }
        let shared = tabs.router.router(for: .home)
        let child = try #require(stored.last)
        let registrations = child.registrations.count

        _ = child.navigator
        _ = child.navigator

        #expect(child.navigator.push(ProductRoute(id: 1)) == .applied)
        #expect(child.navigator.pop() == .applied)
        #expect(shared.state.path.isEmpty)
        #expect(child.registrations.count == registrations)
        #expect(child.registrations.last === shared)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test
    func sharedStackNamesEachTabChild() {
        let tabs = MainTabsCoordinator(stacks: .shared, giving: .shop) {
            NamedTabChildCoordinator()
        }
        let router = tabs.router
        let shared = router.router(for: .home)
        let nameOnHome = shared.coordinatorName

        router.select(.shop)

        #expect(nameOnHome == "TabChildCoordinator")
        #expect(shared.coordinatorName == "NamedTabChildCoordinator")
    }

    @Test
    func flowPresentedOverSharedTabsIsNamedAfterTabCoordinator() throws {
        let tabs = MainTabsCoordinator(stacks: .shared)
        let router = tabs.router

        router.present(CartRoute())

        let presented = try #require(router.presented)
        #expect(presented.coordinatorName == "MainTabsCoordinator")
    }

    @Test
    func removingSharedStackOwnerTabKeepsStack() {
        let tabs = MainTabsCoordinator(stacks: .shared)
        let router = tabs.router
        let shared = router.router(for: .home)

        let withoutHome: [MainTab] = [.shop, .profile]
        router.setTabs(withoutHome)
        RouterTable.shared.sweep()

        #expect(shared.isActive)
        #expect(router.router(for: .shop) === shared)
        #expect(shared.push(ProductRoute(id: 1)) == .applied)
    }

    // MARK: - Refusals

    @Test(arguments: Self.bothLayouts)
    func sameCoordinatorForTwoTabsIsRefused(stacks: TabStacks) throws {
        let child = TabChildCoordinator()
        let tabs = MainTabsCoordinator(stacks: stacks) { tab, _ in
            tab == .profile ? TabChildCoordinator() : child
        }

        let router = tabs.router

        #expect(router.router(for: .home) === child.router)
        #expect(router.router(for: .shop).isActive)
        if stacks == .perTab {
            #expect(router.router(for: .shop) !== child.router)
        }
        let expected: [NavigationIssue.Kind] = [.coordinatorDrawnTwice]
        #expect(tabs.reportedKinds == expected)
        let issue = try #require(tabs.reported.last)
        #expect(issue.message.contains("TabChildCoordinator"))
        #expect(issue.message.contains("shop"))
        let wording = stacks == .shared ? "shared stack" : "a stack of its own"
        #expect(issue.message.contains(wording))
    }

    @Test
    func removingOneOfTwoTabsSharingACoordinatorKeepsIt() {
        let reused = ReusedChildMaker()
        let tabs = MainTabsCoordinator { tab, _ in
            tab == .profile ? TabChildCoordinator() : reused.make()
        }
        weak let child = child(of: tabs, for: .home)

        let withoutShop: [MainTab] = [.home, .profile]
        tabs.router.setTabs(withoutShop)
        RouterTable.shared.sweep()

        #expect(child != nil)
        #expect(child?.router.isActive == true)
    }

    @Test
    func storedTabRouterIsReportedAndJoins() throws {
        let stored = TabRouter(tabs: MainTab.allCases, selection: .home, configuration: .permissive)
        let reported = Recorder<NavigationIssue>()
        stored.tree.onReported { issue in
            reported.record(issue)
        }
        let tabs = StoredTabsCoordinator(router: stored)
        let askedBeforeTouch = tabs.asked.values

        let navigator = tabs.navigator(for: .shop)
        _ = tabs.navigator(for: .shop)

        #expect(askedBeforeTouch.isEmpty)
        #expect(tabs.asked.values == MainTab.allCases)
        let expected: [NavigationIssue.Kind] = [.routerNotFromWaypoint]
        #expect(reported.values.map(\.kind) == expected)
        let issue = try #require(reported.last)
        #expect(issue.message.contains("StoredTabsCoordinator"))
        #expect(stored.router(for: .shop).coordinatorName == "TabChildCoordinator")
        #expect(navigator.push(ProductRoute(id: 1)) == .applied)
    }

    @Test
    func tabChildStoredRouterIsReportedAndJoins() {
        let stored = StackRouter(configuration: .permissive)
        let issues = Recorder<NavigationIssue>()
        stored.tree.onReported { issue in
            issues.record(issue)
        }
        let tabs = MainTabsCoordinator(giving: .shop) {
            StoredRouterCoordinator(router: stored)
        }

        let router = tabs.router

        #expect(router.router(for: .shop) === stored)
        #expect(stored.parent === router)
        let expected: [NavigationIssue.Kind] = [.routerNotFromWaypoint]
        #expect(issues.values.map(\.kind) == expected)
        #expect(tabs.reported.values.isEmpty)
    }

    @Test(arguments: Self.bothLayouts)
    func tabChildStoringItsOwnTabRouterIsAccepted(stacks: TabStacks) {
        let children = Recorder<StoredRouterCoordinator>()
        let tabs = MainTabsCoordinator(stacks: stacks) { tab, parent in
            let child = StoredRouterCoordinator(router: parent.router.router(for: tab))
            children.record(child)
            return child
        }

        let router = tabs.router

        let stack = router.router(for: .shop)
        #expect(stack.isActive)
        #expect(stack.coordinatorName == "StoredRouterCoordinator")
        #expect(tabs.reported.values.isEmpty)
        for child in children.values {
            #expect(child.registrations.last === child.router)
            #expect(child.navigator.push(ProductRoute(id: 1)) == .applied)
        }
    }

    @Test
    func tabChildWithSiblingTabRouterIsRefused() {
        let tabs = MainTabsCoordinator { tab, parent in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            return StoredRouterCoordinator(router: parent.router.router(for: .home))
        }

        let router = tabs.router

        #expect(router.router(for: .shop) !== router.router(for: .home))
        #expect(router.router(for: .shop).isActive)
        #expect(tabs.reportedKinds.contains(.routerOwnedByAnotherCoordinator))
    }

    @Test
    func tabRouterOfAnotherTabCoordinatorIsNotAdopted() throws {
        let owner = MainTabsCoordinator()
        let taken = owner.router
        let homeStack = taken.router(for: .home)
        let thief = GivenTabsCoordinator(given: taken)

        _ = thief.router

        #expect(thief.asked.values.isEmpty)
        #expect(taken.router(for: .home) === homeStack)
        #expect(homeStack.isActive)
        #expect(taken.coordinatorName == "MainTabsCoordinator")
        let expected: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(owner.reportedKinds == expected)
        let issue = try #require(owner.reported.last)
        #expect(issue.message.contains("GivenTabsCoordinator"))
    }

    @Test
    func tabChildWithLaterSiblingTabRouterIsRefused() throws {
        let tabs = MainTabsCoordinator { tab, parent in
            guard tab == .home else {
                return TabChildCoordinator()
            }
            return StoredRouterCoordinator(router: parent.router.router(for: .shop))
        }

        let router = tabs.router

        let shop = router.router(for: .shop)
        #expect(shop !== router.router(for: .home))
        #expect(shop.isActive)
        #expect(shop.coordinatorName == "TabChildCoordinator")
        let expected: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(tabs.reportedKinds == expected)
        let issue = try #require(tabs.reported.last)
        #expect(issue.message.contains("StoredRouterCoordinator"))
    }

    @Test
    func tabChildWithAnotherCoordinatorsRouterGetsItsOwn() {
        let owner = ShopListCoordinator()
        let taken = owner.router
        let issues = Recorder<NavigationIssue>()
        taken.tree.onReported { issue in
            issues.record(issue)
        }
        let tabs = MainTabsCoordinator(giving: .shop) {
            GivenRouterCoordinator(given: taken)
        }

        let router = tabs.router

        #expect(router.router(for: .shop) !== taken)
        #expect(router.router(for: .shop).isActive)
        #expect(taken.parent == nil)
        let expected: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(issues.values.map(\.kind) == expected)
    }

    @Test
    func tabChildWithRouterOfAnotherTreeGetsItsOwn() throws {
        let other = TabRouter(tabs: MainTab.allCases, selection: .home)
        let taken = other.router(for: .home)
        let tabs = MainTabsCoordinator(giving: .shop) {
            GivenRouterCoordinator(given: taken)
        }

        let router = tabs.router

        #expect(router.router(for: .shop) !== taken)
        #expect(router.router(for: .shop).isActive)
        #expect(taken.parent === other)
        let expected: [NavigationIssue.Kind] = [.routerInAnotherTree]
        #expect(tabs.reportedKinds == expected)
        let issue = try #require(tabs.reported.last)
        #expect(issue.message.contains("GivenRouterCoordinator"))
    }

    // MARK: - Reads in deinit

    @Test
    func readInDeinitOfATabCoordinatorWithARouterGetsItInert() throws {
        let outcomes = Recorder<(NavigationOutcome, TabRouter<MainTab>)>()
        let router = makeAndDropDeinitReadingTabs(outcomes: outcomes, readsFirst: true)

        let (outcome, read) = try #require(outcomes.last)
        #expect(outcome == .ignored)
        #expect(read === router)
        #expect(!router.isActive)
        #expect(!router.router(for: .home).isActive)
        #expect(router.selection == .home)
    }

    @Test
    func firstReadInDeinitOfATabCoordinatorGetsAnInertRouter() throws {
        let outcomes = Recorder<(NavigationOutcome, TabRouter<MainTab>)>()
        _ = makeAndDropDeinitReadingTabs(outcomes: outcomes, readsFirst: false)

        let (outcome, read) = try #require(outcomes.last)
        #expect(outcome == .ignored)
        #expect(!read.isActive)
    }

    // MARK: - Helpers

    /// Reads `tabs`' router and returns the child it keeps for `tab`, without keeping it.
    private func child(of tabs: MainTabsCoordinator, for tab: MainTab) -> TabChildCoordinator? {
        _ = tabs.router
        let entry = RouterTable.shared.entry(for: ObjectIdentifier(tabs))
        return entry?.children[AnyHashable(tab)] as? TabChildCoordinator
    }

    /// Makes a tab coordinator, reads its router, drops it, and returns its shop tab's child.
    private func makeAndDropTabCoordinatorChild() -> TabChildCoordinator? {
        child(of: MainTabsCoordinator(), for: .shop)
    }

    /// Makes a tab coordinator that selects in `deinit`, reading its router first when
    /// `readsFirst`, and drops it. Returns the router it read first, or a new one.
    private func makeAndDropDeinitReadingTabs(
        outcomes: Recorder<(NavigationOutcome, TabRouter<MainTab>)>,
        readsFirst: Bool
    ) -> TabRouter<MainTab> {
        let coordinator = DeinitReadingTabsCoordinator(outcomes: outcomes)
        return readsFirst ? coordinator.router : TabRouter(tabs: MainTab.allCases, selection: .home)
    }
}
