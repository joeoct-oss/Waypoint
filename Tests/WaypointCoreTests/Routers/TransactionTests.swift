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

/// Several changes applied as one (planning #300).
@Suite("Transactions")
@MainActor
struct TransactionTests {
    @Test
    func transactionAppliesOnceWithAllChanges() {
        let router = StackRouter(configuration: .permissive)
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
        let router = StackRouter(configuration: .permissive)
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
        let router = StackRouter(configuration: .permissive)
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
        let router = StackRouter(configuration: .permissive)

        #expect(router.transaction { _ in } == .alreadyThere)
    }

    @Test
    func transactionCanNavigateAPresentedFlow() throws {
        let router = StackRouter(configuration: .permissive)

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
    func transactionPushesSeveralRoutesAtOnce() {
        let router = StackRouter(configuration: .permissive)

        let outcome = router.transaction {
            $0.push {
                HomeRoute()
                ProductRoute(id: 1)
            }
        }

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test
    func transactionPopsToTheLastRouteOfAType() {
        let router = StackRouter(configuration: .permissive)
        router.push {
            ProductRoute(id: 1)
            ProductRoute(id: 2)
            SettingsRoute()
        }

        let outcome = router.transaction {
            $0.popTo(ProductRoute.self) { $0.id == 1 }
        }

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test
    func transactionDismissesWhatItsRouterPresents() {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())

        let outcome = router.transaction {
            $0.dismiss()
            $0.push(ProductRoute(id: 1))
        }

        #expect(outcome == .applied)
        #expect(router.presented == nil)
        #expect(router.state.path.count == 1)
    }

    @Test
    func transactionDismissesThePresentedFlowFromInside() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        let outcome = child.transaction {
            $0.dismissFlow()
        }

        #expect(outcome == .applied)
        #expect(router.presented == nil)
        #expect(!child.isActive)
    }

    @Test
    func stepOnATabOfAStackFailsAndRollsBack() {
        let router = StackRouter(configuration: .permissive)

        let outcome = router.transaction {
            $0.push(HomeRoute())
            $0.router(for: MainTab.shop).push(ProductRoute(id: 1))
        }

        #expect(outcome.failure?.issue.kind == .unknownTab)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func rolledBackPresentationLeavesNoChild() {
        let router = StackRouter(configuration: .permissive)

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
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)
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
        let router = StackRouter(configuration: .permissive)

        let outcome = router.transaction {
            $0.select(MainTab.shop)
        }

        #expect(outcome.failure?.issue.kind == .unknownTab)
    }

    @Test
    func transactionDuringChangeIsQueued() {
        let router = StackRouter(configuration: .permissive)
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
