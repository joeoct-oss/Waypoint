//
//  PresentationAndTabReducerTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The pure presentation and tab reducers (planning #298).
@Suite("Presentation and tab reducers")
struct PresentationAndTabReducerTests {
    let sheet = Presentation(style: .sheet, flow: FlowID("filter"), route: AnyRoute(SettingsRoute()))

    @Test
    func presentSetsPresentation() {
        let result = PresentationReducer.reduce(StackState(), .present(sheet))

        let changes: [NavigationChange] = [.presented(sheet)]
        #expect(result == .changed(StackState(presentation: sheet), changes))
    }

    @Test
    func presentWhilePresentingIsRejected() {
        let other = Presentation(style: .fullScreenCover, flow: FlowID("login"))

        let result = PresentationReducer.reduce(StackState(presentation: sheet), .present(other))

        #expect(result == .rejected(.alreadyPresenting(FlowID("filter"))))
    }

    @Test
    func dismissClearsPresentation() {
        let result = PresentationReducer.reduce(StackState(presentation: sheet), .dismiss)

        let changes: [NavigationChange] = [.dismissed(FlowID("filter"))]
        #expect(result == .changed(StackState(), changes))
    }

    @Test
    func dismissWithNothingPresentedIsAlreadyThere() {
        #expect(PresentationReducer.reduce(StackState(), .dismiss) == .unchanged)
    }

    @Test
    func presentationWorksOnTabState() {
        let tabs = TabState(tabs: MainTab.homeAndShop, selection: .home)

        let result = PresentationReducer.reduce(tabs, .present(sheet))

        let expected = TabState(tabs: MainTab.homeAndShop, selection: .home, presentation: sheet)
        let changes: [NavigationChange] = [.presented(sheet)]
        #expect(result == .changed(expected, changes))
    }

    @Test
    func selectTabChangesSelection() {
        let state = TabState(tabs: MainTab.allCases, selection: .home)

        let result = TabReducer.reduce(state, .select(.shop))

        let expected = TabState(tabs: MainTab.allCases, selection: .shop)
        let changes: [NavigationChange] = [.tabSelected(from: "home", to: "shop")]
        #expect(result == .changed(expected, changes))
    }

    @Test
    func selectSelectedTabIsAlreadyThere() {
        let state = TabState(tabs: MainTab.homeAndShop, selection: .home)

        #expect(TabReducer.reduce(state, .select(.home)) == .unchanged)
    }

    @Test
    func selectUnknownTabIsRejected() {
        let state = TabState(tabs: MainTab.homeAndShop, selection: .home)

        #expect(TabReducer.reduce(state, .select(.profile)) == .rejected(.unknownTab("profile")))
    }

    @Test
    func setTabsKeepsSelectionWhenStillThere() {
        let state = TabState(tabs: MainTab.homeAndShop, selection: .shop)

        let newTabs: [MainTab] = [.shop, .profile]

        let result = TabReducer.reduce(state, .setTabs(newTabs))

        let noChanges: [NavigationChange] = []
        #expect(result == .changed(TabState(tabs: newTabs, selection: .shop), noChanges))
    }

    @Test
    func setTabsSelectsFirstWhenSelectionRemoved() {
        let state = TabState(tabs: MainTab.homeAndShop, selection: .shop)

        let newTabs: [MainTab] = [.home, .profile]

        let result = TabReducer.reduce(state, .setTabs(newTabs))

        let expected = TabState(tabs: newTabs, selection: .home)
        let changes: [NavigationChange] = [.tabSelected(from: "shop", to: "home")]
        #expect(result == .changed(expected, changes))
    }

    @Test
    func setTabsToNoTabsIsRejected() {
        let state = TabState(tabs: MainTab.homeAndShop, selection: .home)
        let noTabs: [MainTab] = []

        #expect(TabReducer.reduce(state, .setTabs(noTabs)) == .rejected(.noTabs))
    }

    @Test
    func setSameTabsIsAlreadyThere() {
        let state = TabState(tabs: MainTab.homeAndShop, selection: .home)

        #expect(TabReducer.reduce(state, .setTabs(MainTab.homeAndShop)) == .unchanged)
    }
}
