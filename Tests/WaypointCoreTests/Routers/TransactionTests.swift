//
//  TransactionTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Several changes applied as one (#47).
@Suite("Transactions")
@MainActor
struct TransactionTests {
    @Test
    func transactionAppliesOnceWithAllChanges() {
        let router = StackRouter()
        router.push(HomeRoute())
        var applied: [[AppliedChange]] = []
        router.tree.didApply = { changes in
            applied.append(changes)
        }

        let outcome = router.transaction {
            $0.popToRoot()
            $0.push(ProductRoute(id: 1))
            $0.push(ProductRoute(id: 2))
        }

        let main = router.flowID
        #expect(outcome == .applied)
        #expect(router.state.path == [AnyRoute(ProductRoute(id: 1)), AnyRoute(ProductRoute(id: 2))])
        #expect(applied == [[
            AppliedChange(flow: main, change: .popped([AnyRoute(HomeRoute())])),
            AppliedChange(flow: main, change: .pushed([AnyRoute(ProductRoute(id: 1))])),
            AppliedChange(flow: main, change: .pushed([AnyRoute(ProductRoute(id: 2))])),
        ]])
    }

    @Test
    func observationFiresOncePerTransaction() {
        let router = StackRouter()
        let fired = FireCounter()
        withObservationTracking {
            _ = router.state
        } onChange: {
            fired.increment()
        }

        router.transaction {
            $0.push(HomeRoute())
            $0.push(ProductRoute(id: 1))
            $0.pop()
        }

        #expect(fired.calls == 1)
        #expect(router.state.path == [AnyRoute(HomeRoute())])
    }

    @Test
    func failedStepRollsBackTransaction() throws {
        let router = StackRouter()
        router.push(HomeRoute())

        let line: UInt = #line + 3
        let outcome = router.transaction {
            $0.push(ProductRoute(id: 1))
            $0.popTo(SettingsRoute())
            $0.push(ProductRoute(id: 2))
        }

        let issue = try #require(outcome.failure?.issue)
        #expect(issue.kind == .routeNotInPath)
        #expect(issue.line == line)
        #expect(router.state.path == [AnyRoute(HomeRoute())])
    }

    @Test
    func emptyTransactionIsAlreadyThere() {
        let router = StackRouter()

        #expect(router.transaction { _ in } == .alreadyThere)
    }

    @Test
    func transactionCanNavigateAPresentedFlow() throws {
        let router = StackRouter()

        router.transaction {
            $0.present(SettingsRoute())
            $0.presented?.push(ProductRoute(id: 1))
        }

        let child = try #require(router.presented)
        #expect(child.state.path == [AnyRoute(ProductRoute(id: 1))])
        #expect(child.isActive)
    }

    @Test
    func rolledBackPresentationLeavesNoChild() {
        let router = StackRouter()

        router.transaction {
            $0.present(SettingsRoute())
            $0.pop()
        }

        #expect(router.presented == nil)
        #expect(router.state.presentation == nil)
        router.present(SettingsRoute())
        #expect(router.presented?.flowID == FlowID("settings"))
    }

    @Test
    func tabTransactionChangesTabsAndStacksTogether() {
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .home)
        tabs.present(SettingsRoute())

        let outcome = tabs.transaction {
            $0.dismissAll()
            $0.select(MainTab.shop)
            $0.router(for: MainTab.shop).setPath {
                HomeRoute()
                ProductRoute(id: 42)
            }
        }

        #expect(outcome == .applied)
        #expect(tabs.presented == nil)
        #expect(tabs.selection == .shop)
        #expect(tabs.router(for: .shop).state.path == [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 42))])
    }

    @Test
    func selectOnAStackTransactionFails() {
        let router = StackRouter()

        let outcome = router.transaction {
            $0.select(MainTab.shop)
        }

        #expect(outcome.failure?.issue.kind == .unknownTab)
    }

    @Test
    func transactionDuringChangeIsQueued() {
        let router = StackRouter()
        var inner: NavigationOutcome?
        router.tree.didApply = { _ in
            guard inner == nil else {
                return
            }
            inner = router.transaction {
                $0.push(SettingsRoute())
            }
        }

        router.push(HomeRoute())

        #expect(inner == .queued)
        #expect(router.state.path == [AnyRoute(HomeRoute()), AnyRoute(SettingsRoute())])
    }
}
