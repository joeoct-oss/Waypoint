//
//  TransactionTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
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
        let applied = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            applied.record(changes)
        }

        let outcome = router.transaction {
            $0.popToRoot()
            $0.push(ProductRoute(id: 1))
            $0.push(ProductRoute(id: 2))
        }

        let main = router.flowID
        let home = [AnyRoute(HomeRoute())]
        let first = [AnyRoute(ProductRoute(id: 1))]
        let second = [AnyRoute(ProductRoute(id: 2))]
        #expect(outcome == .applied)
        #expect(router.state.path == first + second)
        let expectedBatch = [
            AppliedChange(flow: main, change: .popped(home)),
            AppliedChange(flow: main, change: .pushed(first)),
            AppliedChange(flow: main, change: .pushed(second)),
        ]
        let expectedBatches = [expectedBatch]
        #expect(applied.values == expectedBatches)
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
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
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
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
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
        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(child.state.path == expectedPath)
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
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home)
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
        let expectedPath = [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 42))]
        #expect(tabs.router(for: .shop).state.path == expectedPath)
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
        let inner = Recorder<NavigationOutcome>()
        let once = Once()
        router.tree.onApplied { _ in
            guard once.claim() else {
                return
            }
            let outcome = router.transaction {
                $0.push(SettingsRoute())
            }
            inner.record(outcome)
        }

        router.push(HomeRoute())

        let expectedOutcomes: [NavigationOutcome] = [.queued]
        #expect(inner.values == expectedOutcomes)
        let expectedPath = [AnyRoute(HomeRoute()), AnyRoute(SettingsRoute())]
        #expect(router.state.path == expectedPath)
    }
}
