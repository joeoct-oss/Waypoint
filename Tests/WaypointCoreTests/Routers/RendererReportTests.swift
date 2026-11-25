//
//  RendererReportTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// Renderer reports: what the user changes directly comes back to the router (planning #291).
@Suite("Renderer reports")
@MainActor
struct RendererReportTests {
    /// Counts a renderer may report for its first screen: zero, and below zero, which reads as
    /// zero.
    nonisolated static let firstScreenCounts = [0, -1]

    /// How each log format marks a change the user made.
    nonisolated static let userMarkers = [(LogFormat.readable, ", by user"), (LogFormat.structured, "origin=user")]

    @Test
    func swipeBackPopsOne() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())
        router.push(ProductRoute(id: 1))
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }

        let outcome = router.rendererDidPop(toCount: 1)

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
        let popped = [AnyRoute(ProductRoute(id: 1))]
        let change = AppliedChange(flow: router.flowID, change: .popped(popped), origin: .user)
        let expectedBatches = [[change]]
        #expect(batches.calls == expectedBatches)
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
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }

        router.rendererDidPop(toCount: 1)

        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
        #expect(batches.callCount == 1)
        #expect(batches.lastCall?.map(\.origin) == [.user])
    }

    /// A count below zero reads as zero.
    @Test(arguments: Self.firstScreenCounts)
    func backToFirstScreenEmptiesPath(count: Int) {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))

        router.rendererDidPop(toCount: count)

        #expect(router.state.path.isEmpty)
    }

    @Test
    func reportMatchingStateIsNoOp() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }
        let reported = Spy<NavigationIssue.Kind, Void>()
        router.tree.onReported { issue in
            reported(issue.kind)
        }

        #expect(router.rendererDidPop(toCount: 1) == .alreadyThere)
        #expect(batches.callCount == 0)
        #expect(reported.callCount == 0)
    }

    @Test
    func staleCountKeepsPathWithIssue() {
        let router = StackRouter(flow: FlowID("shop"), configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }

        let line: UInt = #line + 1
        let outcome = router.rendererDidPop(toCount: 3)

        #expect(outcome == .alreadyThere)
        #expect(router.state.path.count == 1)
        #expect(reported.lastCall?.kind == .rendererMismatch)
        #expect(reported.lastCall?.flow == FlowID("shop"))
        #expect(reported.lastCall?.line == line)
    }

    @Test
    func sheetDragDismisses() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }

        #expect(router.rendererDidDismiss() == .applied)
        #expect(router.presented == nil)
        #expect(router.state.presentation == nil)
        #expect(!child.isActive)
        #expect(batches.lastCall?.map(\.origin) == [.user])
    }

    @Test
    func dismissWithNothingPresentedIsNoOp() {
        let router = StackRouter(configuration: .permissive)

        #expect(router.rendererDidDismiss() == .alreadyThere)
    }

    @Test
    func tabTapSelectsTab() {
        let tabs = TabRouter(selection: MainTab.home, configuration: .permissive)
        let batches = Spy<[AppliedChange], Void>()
        tabs.tree.onApplied { changes in
            batches(changes)
        }

        #expect(tabs.rendererDidSelect(.shop) == .applied)
        #expect(tabs.selection == .shop)
        let change = AppliedChange(flow: tabs.flowID, change: .tabSelected(from: "home", to: "shop"), origin: .user)
        let expectedBatches = [[change]]
        #expect(batches.calls == expectedBatches)
    }

    @Test
    func tabTapOnASharedStackPopsIt() {
        let tabs = TabRouter(selection: MainTab.home, stacks: .shared, configuration: .permissive)
        let shared = tabs.router(for: .home)
        shared.push(ProductRoute(id: 1))

        #expect(tabs.rendererDidSelect(.shop) == .applied)

        #expect(tabs.selection == .shop)
        #expect(shared.state.path.isEmpty)
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

    /// The readable log says "by user", the structured log `origin=user`.
    @Test(arguments: Self.userMarkers)
    func userChangesAreLoggedAsTheUsers(format: LogFormat, marker: String) {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration.default.withHandler(handler).withMinimumLevel(.debug).withFormat(format)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(ProductRoute(id: 1))

        router.rendererDidPop(toCount: 0)

        #expect(handler.texts.contains { $0.contains(marker) })
    }

    @Test
    func missingDestinationIsReportedWithTheFix() {
        let router = StackRouter(flow: FlowID("shop"), configuration: .permissive)
        router.push(ProductRoute(id: 7))
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }
        let reported = Spy<NavigationIssue, Void>()
        router.tree.onReported { issue in
            reported(issue)
        }

        let line: UInt = #line + 1
        let issue = router.rendererFoundNoDestination(for: AnyRoute(ProductRoute(id: 7)))

        #expect(issue.kind == .missingDestination)
        #expect(issue.flow == FlowID("shop"))
        #expect(issue.line == line)
        #expect(issue.message.contains(".destination(ProductRoute.self)"))
        #expect(!issue.message.contains("7"))
        let expectedIssues = [issue]
        #expect(reported.calls == expectedIssues)
        #expect(batches.callCount == 0)
        #expect(router.state.path.count == 1)
    }
}
