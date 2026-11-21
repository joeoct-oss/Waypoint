//
//  SharedTabStackTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Testing
import WaypointTestSupport

@testable import WaypointCore

/// `TabRouter(stacks: .shared)`: the tabs share one stack above the tab bar (#276).
@Suite("Shared tab stack")
@MainActor
struct SharedTabStackTests {
    @Test
    func perTabIsTheDefault() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)

        #expect(tabs.stacks == .perTab)
        #expect(tabs.router(for: .home) !== tabs.router(for: .shop))
    }

    @Test
    func everyTabGetsTheSameRouter() {
        let tabs = TabRouter(selection: MainTab.home, stacks: .shared, configuration: .permissive)

        let shared = tabs.router(for: .home)

        #expect(tabs.stacks == .shared)
        #expect(tabs.router(for: .shop) === shared)
        #expect(tabs.router(for: .profile) === shared)
        #expect(shared.parent === tabs)
        #expect(shared.flowID == FlowID("stack"))
        #expect(tabs.children.count == 1)
    }

    @Test
    func aPushFromAnyTabLandsOnTheSharedStack() {
        let tabs = TabRouter(selection: MainTab.home, stacks: .shared, configuration: .permissive)

        tabs.router(for: .shop).push(ProductRoute(id: 1))

        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(tabs.router(for: .home).state.path == expectedPath)
    }

    @Test
    func selectingAnotherTabPopsThePushedScreens() {
        let tabs = TabRouter(selection: MainTab.home, stacks: .shared, configuration: .permissive)
        let shared = tabs.router(for: .home)
        shared.push(ProductRoute(id: 1))
        let fired = FireCounter()
        withObservationTracking {
            _ = tabs.state
            _ = shared.state
        } onChange: {
            fired.increment()
        }

        #expect(tabs.select(.shop) == .applied)

        #expect(tabs.selection == .shop)
        #expect(shared.state.path.isEmpty)
        #expect(fired.calls == 1)
    }

    @Test
    func reselectingTheSelectedTabKeepsThePushedScreensWithoutPopToRoot() {
        let tabs = TabRouter(
            selection: MainTab.home,
            stacks: .shared,
            popsToRootOnReselect: false,
            configuration: .permissive
        )
        let shared = tabs.router(for: .home)
        shared.push(ProductRoute(id: 1))

        #expect(tabs.select(.home) == .alreadyThere)

        #expect(shared.state.path.count == 1)
    }

    @Test
    func selectingThenSettingThePathInOneTransactionKeepsThePath() {
        let tabs = TabRouter(selection: MainTab.home, stacks: .shared, configuration: .permissive)
        tabs.router(for: .home).push(SettingsRoute())

        tabs.transaction {
            $0.select(MainTab.shop)
            $0.router(for: MainTab.shop).setPath {
                ProductRoute(id: 1)
            }
        }

        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(tabs.selection == .shop)
        #expect(tabs.router(for: .home).state.path == expectedPath)
    }

    @Test
    func removingATabKeepsTheSharedStack() {
        let tabs = TabRouter(selection: MainTab.home, stacks: .shared, configuration: .permissive)
        let shared = tabs.router(for: .home)
        shared.push(ProductRoute(id: 1))

        tabs.setTabs(MainTab.homeAndShop)

        #expect(shared.isActive)
        #expect(tabs.router(for: .shop) === shared)
        #expect(shared.state.path.count == 1)
    }

    @Test
    func theTreeShowsTheSharedStackOnce() {
        let tabs = TabRouter(selection: MainTab.home, stacks: .shared, configuration: .permissive)

        let lines = tabs.debugTree().split(separator: "\n")

        #expect(lines.count == 2)
        #expect(lines[1].contains("stack"))
    }
}
