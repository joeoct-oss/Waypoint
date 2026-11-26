//
//  TabCoordinatingTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// `TabCoordinating`: each tab's child coordinator's router becomes its tab's stack, adopted with
/// its screens, merged into a shared stack, or refused.
@Suite("Tab coordinators and their children")
@MainActor
struct TabCoordinatingTests {
    /// Both tab layouts, for tests that cover each.
    nonisolated static let bothLayouts: [TabStacks] = [.perTab, .shared]

    // MARK: - Children and their routers

    @Test("A tab coordinator gets a tab router and a stack coordinator a stack router")
    func routerKindFollowsProtocol() {
        let tabs = MainTabsCoordinator()
        let stack = ShopListCoordinator()

        let tabRouter: any NavigationRouter = tabs.router
        let stackRouter: any NavigationRouter = stack.router

        #expect(tabRouter is TabRouter<MainTab>)
        #expect(stackRouter is StackRouter)
    }

    @Test("A tab coordinator asks for its tab children only when its router is first read")
    func tabCoordinatorJoinsOnFirstRouterRead() {
        let tabs = MainTabsCoordinator()
        let askedBeforeRead = tabs.asked.calls

        _ = tabs.router
        _ = tabs.router

        #expect(askedBeforeRead.isEmpty)
        #expect(tabs.asked.calls == MainTab.allCases)
    }

    @Test("Each tab's child coordinator gets that tab's active stack router")
    func tabCoordinatorHandsChildrenTheirRouters() throws {
        let children = Spy<(MainTab, any StackCoordinating), Void>()
        let tabs = MainTabsCoordinator { tab, _ in
            let child = TabChildCoordinator()
            children((tab, child))
            return child
        }

        let router = tabs.router

        #expect(children.callCount == MainTab.allCases.count)
        for (tab, child) in children.calls {
            #expect(router.router(for: tab) === child.router)
            #expect(child.router.isActive)
            #expect(child.router.parent === router)
        }
        let home = try #require(children.calls.first)
        #expect(home.1.router.push(ProductRoute(id: 1)) == .applied)
        #expect(router.router(for: .home).state.path.count == 1)
    }

    @Test("The tab router and each tab's stack carry their coordinator's name and tab")
    func tabCoordinatorNamesEachTabRouter() {
        let tabs = MainTabsCoordinator()

        let router = tabs.router

        #expect(router.coordinatorName == "MainTabsCoordinator")
        for tab in MainTab.allCases {
            #expect(router.router(for: tab).coordinatorName == "TabChildCoordinator")
            #expect(router.router(for: tab).flowID.name == tab.rawValue)
        }
    }

    @Test("A tab's stack takes its root name from the tab")
    func defaultRootNameComesFromTab() {
        let tabs = MainTabsCoordinator(giving: .shop) {
            NamedTabChildCoordinator()
        }

        let router = tabs.router

        #expect(router.router(for: .home).rootName == nil)
        #expect(router.router(for: .shop).rootName == "Deals")
    }

    @Test("A tab child that pushes in its init keeps that router and its screen")
    func tabChildPushInInitKeepsItsRouter() {
        let child = Spy<EarlyPushCoordinator, Void>()
        let tabs = MainTabsCoordinator { tab, _ in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            let early = EarlyPushCoordinator()
            child(early)
            return early
        }

        let stack = tabs.router.router(for: .shop)

        #expect(stack === child.lastCall?.made)
        #expect(stack.state.path.count == 1)
        #expect(stack.parent === tabs.router)
        #expect(stack.push(ProductRoute(id: 2)) == .applied)
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("A tab child's own router becomes the tab's stack with its routes registered")
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

    @Test("A tab navigator made before the child is adopted forwards to the tab's stack")
    func tabNavigatorBuiltBeforeChildAdoptionForwards() throws {
        let child = Spy<ParentReadingCoordinator, Void>()
        let tabs = MainTabsCoordinator { tab, parent in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            child(reader)
            return reader
        }
        let router = tabs.router
        let reader = try #require(child.lastCall)

        let outcome = reader.tabNavigator.push(ProductRoute(id: 1))

        #expect(outcome == .applied)
        #expect(router.router(for: .shop) === reader.router)
        #expect(reader.router.state.path.count == 1)
    }

    @Test("A push made before the tab child is adopted is kept on the tab's stack")
    func tabPushBeforeChildAdoptionIsKept() throws {
        let child = Spy<ParentReadingCoordinator, Void>()
        let tabs = MainTabsCoordinator { tab, parent in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            reader.tabNavigator.push(ProductRoute(id: 1))
            child(reader)
            return reader
        }

        let stack = tabs.router.router(for: .shop)

        let reader = try #require(child.lastCall)
        #expect(stack.state.path.count == 1)
        #expect(reader.router === stack)
        #expect(stack.coordinatorName == "ParentReadingCoordinator")
        #expect(reader.router.push(ProductRoute(id: 2)) == .applied)
        #expect(stack.state.path.count == 2)
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("A push from the child of a tab added later is kept")
    func tabPushFromChildOfAddedTabIsKept() throws {
        let child = Spy<ParentReadingCoordinator, Void>()
        let tabs = MainTabsCoordinator(tabs: MainTab.homeAndShop) { tab, parent in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            child(reader)
            reader.tabNavigator.push(ProductRoute(id: 1))
            return reader
        }
        let router = tabs.router

        router.setTabs(MainTab.allCases)

        let reader = try #require(child.lastCall)
        let stack = router.router(for: .profile)
        #expect(stack.state.path.count == 1)
        #expect(reader.router === stack)
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("A tab child reading the parent's router in its init doesn't join the tabs again")
    func tabChildReadingParentRouterInInitDoesNotRejoin() throws {
        let child = Spy<ParentReadingCoordinator, Void>()
        let tabs = MainTabsCoordinator { tab, parent in
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            child(reader)
            return reader
        }

        let router = tabs.router

        #expect(tabs.asked.calls == MainTab.allCases)
        let reader = try #require(child.calls.first)
        #expect(reader.parentRouter === router)
        #expect(tabs.router === router)
    }

    @Test("Two tab coordinators keep routers of their own")
    func innerTabCoordinatorsKeepTheirOwnRouters() {
        let first = MainTabsCoordinator()
        let second = MainTabsCoordinator()

        #expect(first.router !== second.router)
        #expect(first.router.router(for: .home) !== second.router.router(for: .home))
    }

    // MARK: - Adding and removing tabs

    @Test("A tab added later gets its child with a working, named stack")
    func tabAddedLaterGetsItsChild() {
        let tabs = MainTabsCoordinator(tabs: MainTab.homeAndShop)
        let router = tabs.router

        router.setTabs(MainTab.allCases)

        #expect(tabs.asked.calls == MainTab.allCases)
        let profile = router.router(for: .profile)
        #expect(profile.isActive)
        #expect(profile.coordinatorName == "TabChildCoordinator")
        #expect(profile.push(ProductRoute(id: 1)) == .applied)
    }

    @Test("A kept child returned for a tab added back gets the tab's new stack")
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
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("A kept merged child returned for a tab added back gets the tab's new stack", arguments: Self.bothLayouts)
    func keptMergedChildReturnedForATabAddedBackGetsTheNewStack(stacks: TabStacks) throws {
        let kept = Spy<ParentReadingCoordinator, Void>()
        let tabs = MainTabsCoordinator(stacks: stacks) { tab, parent in
            guard tab == .shop else {
                return TabChildCoordinator()
            }
            if let child = kept.lastCall {
                return child
            }
            let reader = ParentReadingCoordinator(tab: tab, parent: parent)
            reader.tabNavigator.push(ProductRoute(id: 1))
            kept(reader)
            return reader
        }
        let router = tabs.router
        let withoutShop: [MainTab] = [.home, .profile]
        router.setTabs(withoutShop)

        router.setTabs(MainTab.allCases)
        router.select(.shop)

        let child = try #require(kept.lastCall)
        let stack = router.router(for: .shop)
        #expect(child.router === stack)
        #expect(stack.isActive)
        #expect(stack.coordinatorName == "ParentReadingCoordinator")
        #expect(child.navigator.push(ProductRoute(id: 2)) == .applied)
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("A removed tab releases its child, and the other tabs still work", arguments: Self.bothLayouts)
    func removedTabReleasesItsChild(stacks: TabStacks) {
        let tabs = MainTabsCoordinator(stacks: stacks)
        weak let released = child(of: tabs, for: .profile)

        tabs.router.setTabs(MainTab.homeAndShop)

        #expect(released == nil)
        #expect(tabs.router.router(for: .home).push(ProductRoute(id: 1)) == .applied)
    }

    @Test("Tab children are released with their tab coordinator")
    func tabChildrenReleasedWithTabs() {
        weak let released = makeAndDropTabCoordinatorChild()

        RouterTable.shared.sweep()

        #expect(released == nil)
    }

    @Test("A sweep keeps the tab router and every tab's stack working")
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

    @Test("A child released while the tabs change gets an inert router and nothing crashes")
    func childDeinitDuringSetTabsDoesNotCrash() throws {
        let outcomes = Spy<(NavigationOutcome, StackRouter), Void>()
        let tabs = MainTabsCoordinator(giving: .profile) {
            DeinitReadingCoordinator(outcomes: outcomes)
        }
        let profile = tabs.router.router(for: .profile)

        tabs.router.setTabs(MainTab.homeAndShop)

        let (outcome, read) = try #require(outcomes.lastCall)
        #expect(outcome == .ignored)
        #expect(!read.isActive)
        #expect(!profile.isActive)
        #expect(tabs.router.router(for: .home).isActive)
    }

    // MARK: - Shared stack

    @Test("A shared stack asks the selected tab for its child first")
    func sharedStackAsksSelectedTabFirst() {
        let tabs = MainTabsCoordinator(selection: .shop, stacks: .shared)

        _ = tabs.router

        let expected: [MainTab] = [.shop, .home, .profile]
        #expect(tabs.asked.calls == expected)
    }

    @Test("A shared stack merges each later child's router into one stack")
    func sharedStackMergesLaterChildRouter() throws {
        let children = Spy<any StackCoordinating, Void>()
        let tabs = MainTabsCoordinator(stacks: .shared) { _, _ in
            let child = TabChildCoordinator()
            children(child)
            return child
        }

        let shared = tabs.router.router(for: .home)

        #expect(children.callCount == MainTab.allCases.count)
        for child in children.calls {
            #expect(child.router === shared)
        }
        let later = try #require(children.lastCall)
        #expect(later.router.push(ProductRoute(id: 1)) == .applied)
        #expect(shared.state.path.count == 1)
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("Screens pushed early by an unselected tab's child on a shared stack are dropped and reported")
    func unselectedTabChildEarlyScreensAreDropped() throws {
        let early = Spy<EarlyPushCoordinator, Void>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPushCoordinator()
            early(child)
            return child
        }

        let shared = tabs.router.router(for: .home)

        #expect(shared.state.path.isEmpty)
        let expected: [NavigationIssue.Kind] = [.tabChildRouterMerged]
        #expect(tabs.reportedKinds == expected)
        let issue = try #require(tabs.reported.lastCall)
        #expect(issue.message.contains("EarlyPushCoordinator"))
        #expect(issue.message.contains("profile"))
        #expect(early.lastCall?.router === shared)
    }

    @Test("A transaction on a merged child's router applies to the shared stack")
    func transactionOnMergedChildRouterForwards() throws {
        let early = Spy<EarlyPushCoordinator, Void>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPushCoordinator()
            early(child)
            return child
        }
        let shared = tabs.router.router(for: .home)
        let child = try #require(early.lastCall)

        let outcome = child.made.transaction { transaction in
            transaction.push(ProductRoute(id: 2))
            transaction.push(ProductRoute(id: 3))
        }

        #expect(outcome == .applied)
        #expect(shared.state.path.count == 2)
    }

    @Test("A flow a merged child presented early leaves the tree and is reported")
    func mergedChildsEarlyPresentedFlowLeavesTheTree() throws {
        let early = Spy<EarlyPresentCoordinator, Void>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPresentCoordinator()
            early(child)
            return child
        }
        _ = tabs.router
        let child = try #require(early.lastCall)
        let presented = try #require(child.presentedFlow)

        let outcome = presented.push(ProductRoute(id: 1))

        #expect(!presented.isActive)
        #expect(outcome == .ignored)
        let expected: [NavigationIssue.Kind] = [.tabChildRouterMerged]
        #expect(tabs.reportedKinds == expected)
    }

    @Test("A merged child's old navigator forwards to the shared stack")
    func staleNavigatorOfMergedChildForwards() throws {
        let early = Spy<EarlyPushCoordinator, Void>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = EarlyPushCoordinator()
            early(child)
            return child
        }
        let shared = tabs.router.router(for: .home)
        let child = try #require(early.lastCall)

        let outcome = child.rootNavigator.push(ProductRoute(id: 2))

        #expect(outcome == .applied)
        #expect(shared.state.path.count == 1)
        #expect(child.made.state.path.count == 1)
    }

    @Test("A merged child's stored router is not adopted again")
    func mergedStoredRouterIsNotReadopted() throws {
        let stored = Spy<StoredRouterCoordinator, Void>()
        let tabs = MainTabsCoordinator(stacks: .shared) { tab, _ in
            guard tab == .profile else {
                return TabChildCoordinator()
            }
            let child = StoredRouterCoordinator(router: StackRouter())
            stored(child)
            return child
        }
        let shared = tabs.router.router(for: .home)
        let child = try #require(stored.lastCall)
        let registrations = child.registrations.callCount

        _ = child.navigator
        _ = child.navigator

        #expect(child.navigator.push(ProductRoute(id: 1)) == .applied)
        #expect(child.navigator.pop() == .applied)
        #expect(shared.state.path.isEmpty)
        #expect(child.registrations.callCount == registrations)
        #expect(child.registrations.lastCall === shared)
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("A shared stack is named after the child of the selected tab")
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

    @Test("A flow presented over shared tabs is named after the tab coordinator")
    func flowPresentedOverSharedTabsIsNamedAfterTabCoordinator() throws {
        let tabs = MainTabsCoordinator(stacks: .shared)
        let router = tabs.router

        router.present(CartRoute())

        let presented = try #require(router.presented)
        #expect(presented.coordinatorName == "MainTabsCoordinator")
    }

    @Test("Removing the tab that owns a shared stack keeps the stack working")
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

    @Test("One coordinator given for two tabs is refused for the second and reported", arguments: Self.bothLayouts)
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
        let issue = try #require(tabs.reported.lastCall)
        #expect(issue.message.contains("TabChildCoordinator"))
        #expect(issue.message.contains("shop"))
        let wording = stacks == .shared ? "shared stack" : "a stack of its own"
        #expect(issue.message.contains(wording))
    }

    @Test("Removing one of two tabs given the same coordinator keeps it alive")
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

    @Test("A tab router stored by its coordinator is reported and still joins the tabs")
    func storedTabRouterIsReportedAndJoins() throws {
        let stored = TabRouter(tabs: MainTab.allCases, selection: .home, configuration: .permissive)
        let reported = Spy<NavigationIssue, Void>()
        stored.tree.onReported { issue in
            reported(issue)
        }
        let tabs = StoredTabsCoordinator(router: stored)
        let askedBeforeTouch = tabs.asked.calls

        let navigator = tabs.navigator(for: .shop)
        _ = tabs.navigator(for: .shop)

        #expect(askedBeforeTouch.isEmpty)
        #expect(tabs.asked.calls == MainTab.allCases)
        let expected: [NavigationIssue.Kind] = [.routerNotFromWaypoint]
        #expect(reported.calls.map(\.kind) == expected)
        let issue = try #require(reported.lastCall)
        #expect(issue.message.contains("StoredTabsCoordinator"))
        #expect(stored.router(for: .shop).coordinatorName == "TabChildCoordinator")
        #expect(navigator.push(ProductRoute(id: 1)) == .applied)
    }

    @Test("A tab child's stored router is reported and still joins its tab")
    func tabChildStoredRouterIsReportedAndJoins() {
        let stored = StackRouter(configuration: .permissive)
        let issues = Spy<NavigationIssue, Void>()
        stored.tree.onReported { issue in
            issues(issue)
        }
        let tabs = MainTabsCoordinator(giving: .shop) {
            StoredRouterCoordinator(router: stored)
        }

        let router = tabs.router

        #expect(router.router(for: .shop) === stored)
        #expect(stored.parent === router)
        let expected: [NavigationIssue.Kind] = [.routerNotFromWaypoint]
        #expect(issues.calls.map(\.kind) == expected)
        #expect(tabs.reported.calls.isEmpty)
    }

    @Test("A tab child that stores its own tab router is accepted without a report", arguments: Self.bothLayouts)
    func tabChildStoringItsOwnTabRouterIsAccepted(stacks: TabStacks) {
        let children = Spy<StoredRouterCoordinator, Void>()
        let tabs = MainTabsCoordinator(stacks: stacks) { tab, parent in
            let child = StoredRouterCoordinator(router: parent.router.router(for: tab))
            children(child)
            return child
        }

        let router = tabs.router

        let stack = router.router(for: .shop)
        #expect(stack.isActive)
        #expect(stack.coordinatorName == "StoredRouterCoordinator")
        #expect(tabs.reported.calls.isEmpty)
        for child in children.calls {
            #expect(child.registrations.lastCall === child.router)
            #expect(child.navigator.push(ProductRoute(id: 1)) == .applied)
        }
    }

    @Test("A tab child holding a sibling tab's router is refused and gets its own")
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

    @Test("A tab router owned by another tab coordinator is not adopted and is reported")
    func tabRouterOfAnotherTabCoordinatorIsNotAdopted() throws {
        let owner = MainTabsCoordinator()
        let taken = owner.router
        let homeStack = taken.router(for: .home)
        let thief = GivenTabsCoordinator(given: taken)

        _ = thief.router

        #expect(thief.asked.calls.isEmpty)
        #expect(taken.router(for: .home) === homeStack)
        #expect(homeStack.isActive)
        #expect(taken.coordinatorName == "MainTabsCoordinator")
        let expected: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(owner.reportedKinds == expected)
        let issue = try #require(owner.reported.lastCall)
        #expect(issue.message.contains("GivenTabsCoordinator"))
    }

    @Test("A tab child holding a later sibling tab's router is refused and reported")
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
        let issue = try #require(tabs.reported.lastCall)
        #expect(issue.message.contains("StoredRouterCoordinator"))
    }

    @Test("A tab child holding another coordinator's router gets its own and is reported")
    func tabChildWithAnotherCoordinatorsRouterGetsItsOwn() {
        let owner = ShopListCoordinator()
        let taken = owner.router
        let issues = Spy<NavigationIssue, Void>()
        taken.tree.onReported { issue in
            issues(issue)
        }
        let tabs = MainTabsCoordinator(giving: .shop) {
            GivenRouterCoordinator(given: taken)
        }

        let router = tabs.router

        #expect(router.router(for: .shop) !== taken)
        #expect(router.router(for: .shop).isActive)
        #expect(taken.parent == nil)
        let expected: [NavigationIssue.Kind] = [.routerOwnedByAnotherCoordinator]
        #expect(issues.calls.map(\.kind) == expected)
    }

    @Test("A tab child holding a router of another tree gets its own and is reported")
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
        let issue = try #require(tabs.reported.lastCall)
        #expect(issue.message.contains("GivenRouterCoordinator"))
    }

    // MARK: - Reads in deinit

    @Test("Reading the router in a tab coordinator's deinit gives it back inert")
    func readInDeinitOfATabCoordinatorWithARouterGetsItInert() throws {
        let outcomes = Spy<(NavigationOutcome, TabRouter<MainTab>), Void>()
        let router = makeAndDropDeinitReadingTabs(outcomes: outcomes, readsFirst: true)

        let (outcome, read) = try #require(outcomes.lastCall)
        #expect(outcome == .ignored)
        #expect(read === router)
        #expect(!router.isActive)
        #expect(!router.router(for: .home).isActive)
        #expect(router.selection == .home)
    }

    @Test("A first router read in a tab coordinator's deinit gives an inert router")
    func firstReadInDeinitOfATabCoordinatorGetsAnInertRouter() throws {
        let outcomes = Spy<(NavigationOutcome, TabRouter<MainTab>), Void>()
        _ = makeAndDropDeinitReadingTabs(outcomes: outcomes, readsFirst: false)

        let (outcome, read) = try #require(outcomes.lastCall)
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
        outcomes: Spy<(NavigationOutcome, TabRouter<MainTab>), Void>,
        readsFirst: Bool
    ) -> TabRouter<MainTab> {
        let coordinator = DeinitReadingTabsCoordinator(outcomes: outcomes)
        return readsFirst ? coordinator.router : TabRouter(tabs: MainTab.allCases, selection: .home)
    }
}
