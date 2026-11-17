//
//  PresentationAndTabReducerTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The pure presentation and tab reducers (#45).
@Suite("Presentation and tab reducers")
struct PresentationAndTabReducerTests {
    let sheet = Presentation(style: .sheet, flow: FlowID("filter"), route: AnyRoute(SettingsRoute()))

    @Test
    func presentSetsPresentation() {
        let result = PresentationReducer.reduce(StackState(), .present(sheet))

        #expect(result == .changed(StackState(presentation: sheet), [.presented(sheet)]))
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

        #expect(result == .changed(StackState(), [.dismissed(FlowID("filter"))]))
    }

    @Test
    func dismissWithNothingPresentedIsAlreadyThere() {
        #expect(PresentationReducer.reduce(StackState(), .dismiss) == .unchanged)
    }

    @Test
    func presentationWorksOnTabState() {
        let tabs = TabState(tabs: [MainTab.home, .shop], selection: .home)

        let result = PresentationReducer.reduce(tabs, .present(sheet))

        #expect(result == .changed(TabState(tabs: [.home, .shop], selection: .home, presentation: sheet), [.presented(sheet)]))
    }

    @Test
    func selectTabChangesSelection() {
        let state = TabState(tabs: [MainTab.home, .shop, .profile], selection: .home)

        let result = TabReducer.reduce(state, .select(.shop))

        let expected = TabState(tabs: [MainTab.home, .shop, .profile], selection: .shop)
        #expect(result == .changed(expected, [.tabSelected(from: "home", to: "shop")]))
    }

    @Test
    func selectSelectedTabIsAlreadyThere() {
        let state = TabState(tabs: [MainTab.home, .shop], selection: .home)

        #expect(TabReducer.reduce(state, .select(.home)) == .unchanged)
    }

    @Test
    func selectUnknownTabIsRejected() {
        let state = TabState(tabs: [MainTab.home, .shop], selection: .home)

        #expect(TabReducer.reduce(state, .select(.profile)) == .rejected(.unknownTab("profile")))
    }

    @Test
    func setTabsKeepsSelectionWhenStillThere() {
        let state = TabState(tabs: [MainTab.home, .shop], selection: .shop)

        let result = TabReducer.reduce(state, .setTabs([.shop, .profile]))

        #expect(result == .changed(TabState(tabs: [.shop, .profile], selection: .shop), []))
    }

    @Test
    func setTabsSelectsFirstWhenSelectionRemoved() {
        let state = TabState(tabs: [MainTab.home, .shop], selection: .shop)

        let result = TabReducer.reduce(state, .setTabs([.home, .profile]))

        let expected = TabState(tabs: [MainTab.home, .profile], selection: .home)
        #expect(result == .changed(expected, [.tabSelected(from: "shop", to: "home")]))
    }

    @Test
    func setTabsToNoTabsIsRejected() {
        let state = TabState(tabs: [MainTab.home], selection: .home)

        #expect(TabReducer.reduce(state, .setTabs([])) == .rejected(.noTabs))
    }

    @Test
    func setSameTabsIsAlreadyThere() {
        let state = TabState(tabs: [MainTab.home, .shop], selection: .home)

        #expect(TabReducer.reduce(state, .setTabs([.home, .shop])) == .unchanged)
    }
}
