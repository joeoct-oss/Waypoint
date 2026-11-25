//
//  TabRouterTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// `TabRouter`: selection, one stack per tab, and presenting above the tabs (planning #299).
@Suite("Tab router")
@MainActor
struct TabRouterTests {
    @Test("Selecting a tab changes the selection, and again is already there")
    func selectTabChangesSelection() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)

        #expect(tabs.select(.shop) == .applied)
        #expect(tabs.selection == .shop)
        #expect(tabs.select(.shop) == .alreadyThere)
    }

    @Test("CaseIterable tabs show every case in order")
    func caseIterableTabsShowEveryCaseInOrder() {
        let tabs = TabRouter(selection: MainTab.shop, configuration: .permissive)

        #expect(tabs.state.tabs == MainTab.allCases)
        #expect(tabs.selection == .shop)
        #expect(tabs.children.count == 3)
    }

    @Test("Tabs given explicitly replace allCases")
    func explicitTabsOverrideAllCases() {
        let tabs = TabRouter(
            tabs: MainTab.homeAndShop,
            selection: .home,
            popsToRootOnReselect: false,
            configuration: .permissive
        )

        #expect(tabs.state.tabs == MainTab.homeAndShop)
        #expect(!tabs.popsToRootOnReselect)
    }

    @Test("Selecting an unknown tab fails and keeps the selection")
    func selectUnknownTabFails() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        let outcome = tabs.select(.profile)

        #expect(outcome.failure?.issue.kind == .unknownTab)
        #expect(tabs.selection == .home)
    }

    @Test("An unknown first selection selects the first tab")
    func initWithUnknownSelectionSelectsFirstTab() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .profile, configuration: .permissive)

        #expect(tabs.selection == .home)
    }

    @Test("Each tab keeps its own stack")
    func tabsKeepIndependentStacks() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        tabs.router(for: .shop).push(ProductRoute(id: 1))
        tabs.router(for: .home).push(SettingsRoute())

        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(tabs.router(for: .shop).state.path == expectedPath)
        let expectedPath2 = [AnyRoute(SettingsRoute())]
        #expect(tabs.router(for: .home).state.path == expectedPath2)
        #expect(tabs.router(for: .shop).parent === tabs)
        #expect(tabs.router(for: .shop).flowID == FlowID("shop"))
        #expect(tabs.children.count == 2)
    }

    @Test("Reselecting a tab pops it to its root")
    func reselectingPopsTabToRoot() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        tabs.router(for: .shop).push(ProductRoute(id: 1))

        #expect(tabs.select(.shop) == .applied)
        #expect(tabs.router(for: .shop).state.path.isEmpty)
    }

    @Test("Popping to root on reselect can be turned off")
    func reselectingCanBeTurnedOff() {
        let tabs = TabRouter(
            tabs: MainTab.homeAndShop,
            selection: .shop,
            popsToRootOnReselect: false,
            configuration: .permissive
        )
        tabs.router(for: .shop).push(ProductRoute(id: 1))

        #expect(tabs.select(.shop) == .alreadyThere)
        #expect(tabs.router(for: .shop).state.path.count == 1)
    }

    @Test("Changing the tabs releases the removed tabs")
    func setTabsReleasesRemovedTabs() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        let shop = tabs.router(for: .shop)
        let newTabs: [MainTab] = [.home, .profile]
        let applied = Spy<[AppliedChange], Void>()
        tabs.tree.onApplied { changes in
            applied(changes)
        }

        #expect(tabs.setTabs(newTabs) == .applied)

        #expect(tabs.selection == .home)
        let moved = [AppliedChange(flow: tabs.flowID, change: .tabSelected(from: "shop", to: "home"))]
        let movedBatches = [moved]
        #expect(applied.calls == movedBatches)
        #expect(shop.push(ProductRoute(id: 1)) == .ignored)
        #expect(tabs.router(for: .profile).isActive)
    }

    @Test("Changing the tabs keeps the selection when its tab stays")
    func setTabsKeepsTheSelectionWhenItStays() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        let newTabs: [MainTab] = [.shop, .profile]

        #expect(tabs.setTabs(newTabs) == .applied)

        #expect(tabs.state.tabs == newTabs)
        #expect(tabs.selection == .shop)
    }

    @Test("Setting the same tabs is already there")
    func setTabsWithTheSameTabsIsAlreadyThere() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        #expect(tabs.setTabs(MainTab.homeAndShop) == .alreadyThere)
    }

    @Test("Setting no tabs fails and keeps the tabs")
    func setTabsWithNoTabsFails() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)
        let noTabs: [MainTab] = []

        let issue = try #require(tabs.setTabs(noTabs).failure?.issue)

        #expect(issue.message.hasPrefix("A tab container needs at least one tab"))
        #expect(tabs.state.tabs == MainTab.homeAndShop)
        #expect(tabs.selection == .home)
    }

    @Test("dismiss closes the flow over the tabs")
    func dismissClosesTheFlowOverTheTabs() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        tabs.present(SettingsRoute())

        #expect(tabs.dismiss() == .applied)

        #expect(tabs.presented == nil)
        #expect(tabs.dismiss() == .alreadyThere)
    }

    @Test("dismissAll closes every flow above the tabs")
    func dismissAllClosesEveryFlowAboveTheTabs() throws {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        tabs.present(SettingsRoute())
        let child = try #require(tabs.presented)
        child.present(HomeRoute())
        let grandchild = try #require(child.presented)

        #expect(tabs.dismissAll() == .applied)

        #expect(tabs.presented == nil)
        #expect(!child.isActive)
        #expect(!grandchild.isActive)
    }

    @Test("Tab stacks have the tab container as parent and root")
    func tabStacksNameTheContainerAsParentAndRoot() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let stack = tabs.router(for: .home)

        #expect(tabs.parent == nil)
        #expect(tabs.root === tabs)
        #expect(stack.parent === tabs)
        #expect(stack.root === tabs)
    }

    @Test("A push fallback set on the tabs applies only to a route not in the path")
    func pushFallbackOnTheTabsOnlySetsForRouteNotInPath() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let reported = Spy<NavigationIssue.Kind, Void>()
        tabs.tree.onReported { issue in
            reported(issue.kind)
        }

        tabs.setFallback(.push, for: .emptyPath)
        tabs.setFallback(.push, for: .routeNotInPath)

        #expect(tabs.fallbackPolicy[.emptyPath] == nil)
        #expect(tabs.fallbackPolicy[.routeNotInPath] == .push)
        let expectedKinds: [NavigationIssue.Kind] = [.invalidSetting]
        #expect(reported.calls == expectedKinds)
    }

    @Test("A sheet over the tabs takes the tabs' presentation defaults")
    func sheetOverTheTabsTakesTheirPresentationDefaults() throws {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let detents: [SheetDetent] = [.medium]
        let defaults = PresentationDefaults(sheet: SheetOptions(detents: detents))

        tabs.setPresentationDefaults(defaults)
        tabs.present(SettingsRoute())

        #expect(tabs.presentationDefaults == defaults)
        let child = try #require(tabs.presented)
        #expect(child.presentationDefaults == defaults)
        #expect(tabs.router(for: .home).presentationDefaults == defaults)
        let presentation = try #require(tabs.state.presentation)
        #expect(tabs.sheetOptions(for: presentation) == defaults.sheet)
    }

    @Test("The router for an unknown tab is inactive")
    func routerForUnknownTabIsInactive() {
        let homeOnly: [MainTab] = [.home]
        let tabs = TabRouter(tabs: homeOnly, selection: .home, configuration: .permissive)

        #expect(tabs.router(for: .shop).push(HomeRoute()) == .ignored)
    }

    @Test("The tab router presents a flow above all tabs")
    func tabRouterPresentsAboveAllTabs() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        #expect(tabs.present(SettingsRoute()) == .applied)

        let child = try #require(tabs.presented)
        #expect(child.parent === tabs)
        #expect(tabs.state.presentation?.flow == child.flowID)
        #expect(child.dismissFlow() == .applied)
        #expect(tabs.presented == nil)
    }

    @Test("Stacks inside tabs share the tabs' tree")
    func stacksInsideTabsShareTheTree() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)
        let shop = tabs.router(for: .shop)

        shop.present(SettingsRoute())

        #expect(shop.root === tabs)
        #expect(try #require(shop.presented).root === tabs)
    }
}
