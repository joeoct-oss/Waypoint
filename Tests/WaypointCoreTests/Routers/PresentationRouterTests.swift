//
//  PresentationRouterTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Presenting and dismissing child flows, and the router tree (planning #299).
@Suite("Presentation in routers")
@MainActor
struct PresentationRouterTests {
    @Test
    func presentSetsPresentationAndCreatesChildRouter() throws {
        let router = StackRouter(configuration: .permissive)

        let outcome = router.present(SettingsRoute(), style: .fullScreenCover)

        let child = try #require(router.presented)
        #expect(outcome == .applied)
        #expect(child.parent === router)
        #expect(child.root === router)
        #expect(router.children.count == 1)
        #expect(child.rootRoute == AnyRoute(SettingsRoute()))
        let expected = Presentation(style: .fullScreenCover, flow: child.flowID, route: AnyRoute(SettingsRoute()))
        #expect(router.state.presentation == expected)
    }

    @Test
    func presentedFlowsAreNamedAfterTheirRoute() throws {
        let router = StackRouter(configuration: .permissive)

        router.present(SettingsRoute())
        let child = try #require(router.presented)
        child.present(SettingsRoute())

        #expect(child.flowID == FlowID("settings"))
        #expect(child.presented?.flowID == FlowID("settings-2"))
    }

    @Test
    func presentWhilePresentingIsRejected() {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let first = router.presented

        let outcome = router.present(HomeRoute())

        #expect(outcome.failure?.issue.kind == .alreadyPresenting)
        #expect(router.presented === first)
    }

    @Test
    func presentedFlowNavigatesOnItsOwn() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        child.push(ProductRoute(id: 3))

        let expectedPath = [AnyRoute(ProductRoute(id: 3))]
        #expect(child.state.path == expectedPath)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func dismissWithNothingPresentedIsAlreadyThere() {
        #expect(StackRouter(configuration: .permissive).dismiss() == .alreadyThere)
    }

    @Test
    func dismissRemovesWholeSubtree() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        child.present(HomeRoute())
        let grandchild = try #require(child.presented)

        #expect(router.dismiss() == .applied)

        #expect(router.presented == nil)
        #expect(router.state.presentation == nil)
        #expect(child.push(ProductRoute(id: 1)) == .ignored)
        #expect(grandchild.push(ProductRoute(id: 1)) == .ignored)
        #expect(!child.isActive)
        #expect(router.isActive)
    }

    @Test
    func dismissFlowAsksThePresenter() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        child.push(ProductRoute(id: 1))

        #expect(child.dismissFlow() == .applied)
        #expect(router.presented == nil)
    }

    @Test
    func dismissFlowOnRootFails() {
        let outcome = StackRouter(configuration: .permissive).dismissFlow()

        #expect(outcome.failure?.issue.kind == .notPresented)
    }

    @Test
    func dismissAllDismissesEverythingAbove() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        try #require(router.presented).present(HomeRoute())

        #expect(router.dismissAll() == .applied)
        #expect(router.presented == nil)
        #expect(router.dismissAll() == .alreadyThere)
    }

    @Test
    func presentationDefaultsAreInherited() throws {
        let router = StackRouter(configuration: .permissive)
        let detents: [SheetDetent] = [.medium, .large]
        let defaults = PresentationDefaults(sheet: SheetOptions(detents: detents))
        router.setPresentationDefaults(defaults)
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        #expect(child.presentationDefaults.sheet.detents == detents)
        #expect(StackRouter(configuration: .permissive).presentationDefaults.sheet == .default)
    }

    @Test
    func sheetOptionsFollowLookupOrder() throws {
        let router = StackRouter(configuration: .permissive)
        let defaultDetents: [SheetDetent] = [.medium]
        let ownDetents: [SheetDetent] = [.fitsContent]
        let defaults = PresentationDefaults(sheet: SheetOptions(detents: defaultDetents))
        router.setPresentationDefaults(defaults)

        router.present(SettingsRoute())
        let inherited = try #require(router.state.presentation)
        router.dismiss()
        router.present(SettingsRoute(), style: .sheet(detents: ownDetents))
        let own = try #require(router.state.presentation)

        #expect(router.sheetOptions(for: inherited).detents == defaultDetents)
        #expect(router.sheetOptions(for: own).detents == ownDetents)
    }
}
