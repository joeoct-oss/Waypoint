//
//  TabRouterTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// `TabRouter`: selection, one stack per tab, and presenting above the tabs (planning #299).
@Suite("Tab router")
@MainActor
struct TabRouterTests {
    @Test
    func selectTabChangesSelection() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)

        #expect(tabs.select(.shop) == .applied)
        #expect(tabs.selection == .shop)
        #expect(tabs.select(.shop) == .alreadyThere)
    }

    @Test
    func caseIterableTabsShowEveryCaseInOrder() {
        let tabs = TabRouter(selection: MainTab.shop, configuration: .permissive)

        #expect(tabs.state.tabs == MainTab.allCases)
        #expect(tabs.selection == .shop)
        #expect(tabs.children.count == 3)
    }

    @Test
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

    @Test
    func selectUnknownTabFails() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        let outcome = tabs.select(.profile)

        #expect(outcome.failure?.issue.kind == .unknownTab)
        #expect(tabs.selection == .home)
    }

    @Test
    func initWithUnknownSelectionSelectsFirstTab() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .profile, configuration: .permissive)

        #expect(tabs.selection == .home)
    }

    @Test
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

    @Test
    func reselectingPopsTabToRoot() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        tabs.router(for: .shop).push(ProductRoute(id: 1))

        #expect(tabs.select(.shop) == .applied)
        #expect(tabs.router(for: .shop).state.path.isEmpty)
    }

    @Test
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

    @Test
    func setTabsReleasesRemovedTabs() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        let shop = tabs.router(for: .shop)
        let newTabs: [MainTab] = [.home, .profile]
        let applied = Recorder<[AppliedChange]>()
        tabs.tree.onApplied { changes in
            applied.record(changes)
        }

        #expect(tabs.setTabs(newTabs) == .applied)

        #expect(tabs.selection == .home)
        let moved = [AppliedChange(flow: tabs.flowID, change: .tabSelected(from: "shop", to: "home"))]
        let movedBatches = [moved]
        #expect(applied.values == movedBatches)
        #expect(shop.push(ProductRoute(id: 1)) == .ignored)
        #expect(tabs.router(for: .profile).isActive)
    }

    @Test
    func setTabsKeepsTheSelectionWhenItStays() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        let newTabs: [MainTab] = [.shop, .profile]

        #expect(tabs.setTabs(newTabs) == .applied)

        #expect(tabs.state.tabs == newTabs)
        #expect(tabs.selection == .shop)
    }

    @Test
    func setTabsWithTheSameTabsIsAlreadyThere() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        #expect(tabs.setTabs(MainTab.homeAndShop) == .alreadyThere)
    }

    @Test
    func setTabsWithNoTabsFails() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)
        let noTabs: [MainTab] = []

        let issue = try #require(tabs.setTabs(noTabs).failure?.issue)

        #expect(issue.message.hasPrefix("A tab container needs at least one tab"))
        #expect(tabs.state.tabs == MainTab.homeAndShop)
        #expect(tabs.selection == .home)
    }

    @Test
    func dismissClosesTheFlowOverTheTabs() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        tabs.present(SettingsRoute())

        #expect(tabs.dismiss() == .applied)

        #expect(tabs.presented == nil)
        #expect(tabs.dismiss() == .alreadyThere)
    }

    @Test
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

    @Test
    func tabStacksNameTheContainerAsParentAndRoot() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let stack = tabs.router(for: .home)

        #expect(tabs.parent == nil)
        #expect(tabs.root === tabs)
        #expect(stack.parent === tabs)
        #expect(stack.root === tabs)
    }

    @Test
    func pushFallbackOnTheTabsOnlySetsForRouteNotInPath() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let reported = Recorder<NavigationIssue.Kind>()
        tabs.tree.onReported { issue in
            reported.record(issue.kind)
        }

        tabs.setFallback(.push, for: .emptyPath)
        tabs.setFallback(.push, for: .routeNotInPath)

        #expect(tabs.fallbackPolicy[.emptyPath] == nil)
        #expect(tabs.fallbackPolicy[.routeNotInPath] == .push)
        let expectedKinds: [NavigationIssue.Kind] = [.invalidSetting]
        #expect(reported.values == expectedKinds)
    }

    @Test
    func sheetOverTheTabsTakesTheirPresentationDefaults() throws {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let defaults = PresentationDefaults(sheet: SheetOptions(detents: [.medium]))

        tabs.setPresentationDefaults(defaults)
        tabs.present(SettingsRoute())

        #expect(tabs.presentationDefaults == defaults)
        let child = try #require(tabs.presented)
        #expect(child.presentationDefaults == defaults)
        #expect(tabs.router(for: .home).presentationDefaults == defaults)
        let presentation = try #require(tabs.state.presentation)
        #expect(tabs.sheetOptions(for: presentation) == defaults.sheet)
    }

    @Test
    func routerForUnknownTabIsInactive() {
        let homeOnly: [MainTab] = [.home]
        let tabs = TabRouter(tabs: homeOnly, selection: .home, configuration: .permissive)

        #expect(tabs.router(for: .shop).push(HomeRoute()) == .ignored)
    }

    @Test
    func tabRouterPresentsAboveAllTabs() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        #expect(tabs.present(SettingsRoute()) == .applied)

        let child = try #require(tabs.presented)
        #expect(child.parent === tabs)
        #expect(tabs.state.presentation?.flow == child.flowID)
        #expect(child.dismissFlow() == .applied)
        #expect(tabs.presented == nil)
    }

    @Test
    func stacksInsideTabsShareTheTree() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)
        let shop = tabs.router(for: .shop)

        shop.present(SettingsRoute())

        #expect(shop.root === tabs)
        #expect(try #require(shop.presented).root === tabs)
    }
}
