//
//  RendererReportTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Renderer reports: what the user changes directly comes back to the router (#38).
@Suite("Renderer reports")
@MainActor
struct RendererReportTests {
    @Test
    func swipeBackPopsOne() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())
        router.push(ProductRoute(id: 1))
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }

        let outcome = router.rendererDidPop(toCount: 1)

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
        let popped = [AnyRoute(ProductRoute(id: 1))]
        let change = AppliedChange(flow: router.flowID, change: .popped(popped), origin: .user)
        let expectedBatches = [[change]]
        #expect(batches.values == expectedBatches)
    }

    @Test
    func backMenuPopsMany() {
        let router = StackRouter(configuration: .permissive)
        router.push {
            HomeRoute()
            ProductRoute(id: 1)
            ProductRoute(id: 2)
            SettingsRoute()
        }
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }

        router.rendererDidPop(toCount: 1)

        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
        #expect(batches.count == 1)
        #expect(batches.last?.map(\.origin) == [.user])
    }

    @Test
    func backToFirstScreenEmptiesPath() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        router.rendererDidPop(toCount: 0)

        #expect(router.state.path.isEmpty)
    }

    @Test
    func reportMatchingStateIsNoOp() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }
        let reported = Recorder<NavigationIssue.Kind>()
        router.tree.onReported { issue in
            reported.record(issue.kind)
        }

        #expect(router.rendererDidPop(toCount: 1) == .alreadyThere)
        #expect(batches.count == 0)
        #expect(reported.count == 0)
    }

    @Test
    func staleCountKeepsPathWithIssue() {
        let router = StackRouter(flow: FlowID("shop"), configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let reported = Recorder<NavigationIssue>()
        router.tree.onReported { issue in
            reported.record(issue)
        }

        let line: UInt = #line + 1
        let outcome = router.rendererDidPop(toCount: 3)

        #expect(outcome == .alreadyThere)
        #expect(router.state.path.count == 1)
        #expect(reported.last?.kind == .rendererMismatch)
        #expect(reported.last?.flow == FlowID("shop"))
        #expect(reported.last?.line == line)
    }

    @Test
    func negativeCountReadsAsZero() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        router.rendererDidPop(toCount: -1)

        #expect(router.state.path.isEmpty)
    }

    @Test
    func sheetDragDismisses() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }

        #expect(router.rendererDidDismiss() == .applied)
        #expect(router.presented == nil)
        #expect(router.state.presentation == nil)
        #expect(!child.isActive)
        #expect(batches.last?.map(\.origin) == [.user])
    }

    @Test
    func dismissWithNothingPresentedIsNoOp() {
        let router = StackRouter(configuration: .permissive)

        #expect(router.rendererDidDismiss() == .alreadyThere)
    }

    @Test
    func tabTapSelectsTab() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let batches = Recorder<[AppliedChange]>()
        tabs.tree.onApplied { changes in
            batches.record(changes)
        }

        #expect(tabs.rendererDidSelect(.shop) == .applied)
        #expect(tabs.selection == .shop)
        let change = AppliedChange(flow: tabs.flowID, change: .tabSelected(from: "home", to: "shop"), origin: .user)
        let expectedBatches = [[change]]
        #expect(batches.values == expectedBatches)
    }

    @Test
    func tabTapOnSelectedTabIsNoOp() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let shopRouter = tabs.router(for: .home)
        shopRouter.push(ProductRoute(id: 1))

        #expect(tabs.rendererDidSelect(.home) == .alreadyThere)
        #expect(shopRouter.state.path.count == 1)
    }

    @Test
    func tabTapOnUnknownTabFails() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)

        let outcome = tabs.rendererDidSelect(.profile)

        #expect(outcome.failure?.issue.kind == .unknownTab)
        #expect(tabs.selection == .home)
    }

    @Test
    func tabContainerSheetDragDismisses() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        tabs.present(SettingsRoute())

        #expect(tabs.rendererDidDismiss() == .applied)
        #expect(tabs.presented == nil)
    }

    @Test
    func detachedRouterIgnoresReports() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        child.push(ProductRoute(id: 1))
        router.dismiss()

        #expect(child.rendererDidPop(toCount: 0) == .ignored)
    }

    @Test
    func userChangesReadAsByUser() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration.default.withHandler(handler).withMinimumLevel(.debug).withSymbols(false)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(ProductRoute(id: 1))

        router.rendererDidPop(toCount: 0)

        #expect(handler.texts.contains { $0.contains("· by user") })
    }

    @Test
    func userChangesLogWithUserOrigin() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration.default.withHandler(handler).withMinimumLevel(.debug).withFormat(.structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(ProductRoute(id: 1))

        router.rendererDidPop(toCount: 0)

        #expect(handler.texts.contains { $0.contains("origin=user") })
    }

    @Test
    func missingDestinationIsReportedWithTheFix() {
        let router = StackRouter(flow: FlowID("shop"), configuration: .permissive)
        router.push(ProductRoute(id: 7))
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }
        let reported = Recorder<NavigationIssue>()
        router.tree.onReported { issue in
            reported.record(issue)
        }

        let line: UInt = #line + 1
        let issue = router.rendererFoundNoDestination(for: AnyRoute(ProductRoute(id: 7)))

        #expect(issue.kind == .missingDestination)
        #expect(issue.flow == FlowID("shop"))
        #expect(issue.line == line)
        #expect(issue.message.contains(".destination(ProductRoute.self)"))
        #expect(!issue.message.contains("7"))
        let expectedIssues = [issue]
        #expect(reported.values == expectedIssues)
        #expect(batches.count == 0)
        #expect(router.state.path.count == 1)
    }
}
