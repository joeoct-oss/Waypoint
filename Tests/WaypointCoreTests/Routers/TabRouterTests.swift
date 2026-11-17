//
//  TabRouterTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// `TabRouter`: selection, one stack per tab, and presenting above the tabs (#46).
@Suite("Tab router")
@MainActor
struct TabRouterTests {
    @Test
    func selectTabChangesSelection() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop, .profile], selection: .home)

        #expect(tabs.select(.shop) == .applied)
        #expect(tabs.selection == .shop)
        #expect(tabs.select(.shop) == .alreadyThere)
    }

    @Test
    func selectUnknownTabFails() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .home)

        let outcome = tabs.select(.profile)

        #expect(outcome.failure?.issue.kind == .unknownTab)
        #expect(tabs.selection == .home)
    }

    @Test
    func initWithUnknownSelectionSelectsFirstTab() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .profile)

        #expect(tabs.selection == .home)
    }

    @Test
    func tabsKeepIndependentStacks() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .home)

        tabs.router(for: .shop).push(ProductRoute(id: 1))
        tabs.router(for: .home).push(SettingsRoute())

        #expect(tabs.router(for: .shop).state.path == [AnyRoute(ProductRoute(id: 1))])
        #expect(tabs.router(for: .home).state.path == [AnyRoute(SettingsRoute())])
        #expect(tabs.router(for: .shop).parent === tabs)
        #expect(tabs.router(for: .shop).flowID == FlowID("shop"))
        #expect(tabs.children.count == 2)
    }

    @Test
    func reselectingPopsTabToRoot() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .shop)
        tabs.router(for: .shop).push(ProductRoute(id: 1))

        #expect(tabs.select(.shop) == .applied)
        #expect(tabs.router(for: .shop).state.path.isEmpty)
    }

    @Test
    func reselectingCanBeTurnedOff() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .shop, popsToRootOnReselect: false)
        tabs.router(for: .shop).push(ProductRoute(id: 1))

        #expect(tabs.select(.shop) == .alreadyThere)
        #expect(tabs.router(for: .shop).state.path.count == 1)
    }

    @Test
    func setTabsReleasesRemovedTabs() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .shop)
        let shop = tabs.router(for: .shop)

        #expect(tabs.setTabs([.home, .profile]) == .applied)

        #expect(tabs.selection == .home)
        #expect(shop.push(ProductRoute(id: 1)) == .ignored)
        #expect(tabs.router(for: .profile).isActive)
    }

    @Test
    func routerForUnknownTabIsInactive() {
        let tabs = TabRouter(tabs: [MainTab.home], selection: .home)

        #expect(tabs.router(for: .shop).push(HomeRoute()) == .ignored)
    }

    @Test
    func tabRouterPresentsAboveAllTabs() throws {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .home)

        #expect(tabs.present(SettingsRoute()) == .applied)

        let child = try #require(tabs.presented)
        #expect(child.parent === tabs)
        #expect(tabs.state.presentation?.flow == child.flowID)
        #expect(child.dismissFlow() == .applied)
        #expect(tabs.presented == nil)
    }

    @Test
    func stacksInsideTabsShareTheTree() throws {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .home)
        let shop = tabs.router(for: .shop)

        shop.present(SettingsRoute())

        #expect(shop.root === tabs)
        #expect(try #require(shop.presented).root === tabs)
    }
}
