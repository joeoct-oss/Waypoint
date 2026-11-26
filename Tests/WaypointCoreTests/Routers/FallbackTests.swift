//
//  FallbackTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// Outcomes and fallbacks.
@Suite("Fallbacks")
@MainActor
struct FallbackTests {
    @Test("A fallback given with the call beats the router's policy")
    func perCallFallbackBeatsRouterPolicy() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())
        router.setFallback(.popToRoot, for: .routeNotInPath)

        let outcome = router.popTo(SettingsRoute(), else: .push)

        #expect(outcome.description == "recovered routeNotInPath by=push")
        let expectedPath = [AnyRoute(HomeRoute()), AnyRoute(SettingsRoute())]
        #expect(router.state.path == expectedPath)
    }

    @Test("The router's policy beats the built-in default")
    func routerPolicyBeatsBuiltInDefault() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())
        router.setFallback(.popToRoot, for: .routeNotInPath)
        router.setFallback(NavigationFallback.none, for: .notEnoughRoutes)

        #expect(router.popTo(SettingsRoute()).description == "recovered routeNotInPath by=popToRoot")
        router.push(HomeRoute())
        #expect(router.pop(count: 5).failure?.issue.kind == .notEnoughRoutes)
    }

    @Test("The built-in fallbacks only pop to root for too few routes")
    func builtInDefaultsAreConservative() {
        #expect(NavigationFallback.builtIn(for: .notEnoughRoutes) == .popToRoot)
        #expect(NavigationFallback.builtIn(for: .routeNotInPath) == NavigationFallback.none)
        #expect(NavigationFallback.builtIn(for: .emptyPath) == NavigationFallback.none)
        #expect(NavigationFallback.builtIn(for: .unregisteredRoute) == NavigationFallback.none)
    }

    @Test("A child flow inherits the fallback policy")
    func childInheritsFallbackPolicy() throws {
        let router = StackRouter(configuration: .permissive)
        router.setFallback(.popToRoot, for: .routeNotInPath)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        child.push(ProductRoute(id: 1))

        #expect(child.popTo(HomeRoute()).description == "recovered routeNotInPath by=popToRoot")
        #expect(child.state.path.isEmpty)

        child.setFallback(NavigationFallback.none, for: .routeNotInPath)
        #expect(child.popTo(HomeRoute()).failure != nil)
    }

    @Test("A fallback runs in the same transaction as its call")
    func fallbackRunsInSameTransaction() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())
        router.push(ProductRoute(id: 1))
        let batches = Spy<[AppliedChange], Void>()
        router.tree.onApplied { changes in
            batches(changes)
        }
        let fired = FireCounter()
        withObservationTracking {
            _ = router.state
        } onChange: {
            fired.increment()
        }

        router.popTo(SettingsRoute(), else: .popToRoot)

        let routes = [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 1))]
        let popped = NavigationChange.popped(routes)
        let batch = [AppliedChange(flow: router.flowID, change: popped, origin: .fallback)]
        let expectedBatches = [batch]
        #expect(batches.calls == expectedBatches)
        #expect(fired.calls == 1)
    }

    @Test("A fallback that fails rolls back and reports both issues")
    func fallbackFailureRollsBack() throws {
        let failures = Spy<NavigationFailure, Void>()
        let configuration = NavigationConfiguration(
            registry: .permissive,
            onNavigationFailure: { failure in
                failures(failure)
            }
        )
        let router = StackRouter(configuration: configuration)

        let outcome = router.popTo(SettingsRoute(), else: .dismissAll)
        let pushOutcome = router.pop(else: .push)

        #expect(outcome.failure == nil)
        #expect(outcome.recoveredIssue?.kind == .routeNotInPath)
        let failure = try #require(pushOutcome.failure)
        #expect(failure.issue.kind == .emptyPath)
        #expect(failure.fallback == .push)
        #expect(failure.fallbackIssue?.kind == .fallbackFailed)
        let expectedValues = [failure]
        #expect(failures.calls == expectedValues)
        #expect(router.state.path.isEmpty)
    }

    @Test("A custom fallback that fails rolls back its own steps")
    func customFallbackFailureRollsBackItsOwnSteps() throws {
        let failures = Spy<NavigationFailure, Void>()
        let configuration = NavigationConfiguration(
            registry: .permissive,
            onNavigationFailure: { failure in
                failures(failure)
            }
        )
        let router = StackRouter(configuration: configuration)
        router.push(HomeRoute())
        let fallback = NavigationFallback.custom("pushThenFail") { transaction, _ in
            transaction.push(ProductRoute(id: 9))
            transaction.popTo(SettingsRoute())
        }

        let outcome = router.popTo(WizardStep.review, else: fallback)

        let failure = try #require(outcome.failure)
        #expect(failure.description.hasSuffix("fallback=custom(pushThenFail) fallbackIssue=routeNotInPath"))
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
        #expect(failures.callCount == 1)
    }

    @Test("A fallback that fails doesn't chain to another")
    func fallbackRunsOnceNoChain() {
        let router = StackRouter(configuration: .permissive)
        router.setFallback(.popToRoot, for: .emptyPath)
        router.setFallback(.popToRoot, for: .routeNotInPath)
        let fallback = NavigationFallback.custom("popMissing") { transaction, _ in
            transaction.popTo(SettingsRoute())
        }

        let outcome = router.pop(else: fallback)

        #expect(outcome.failure?.fallbackIssue?.kind == .routeNotInPath)
    }

    @Test("A custom fallback gets the issue and can navigate")
    func customFallbackGetsTheIssueAndCanNavigate() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 1))
        let seen = Spy<NavigationIssue.Kind, Void>()
        let showHome = NavigationFallback.custom("showHome") { transaction, issue in
            seen(issue.kind)
            transaction.setPath {
                HomeRoute()
            }
        }

        let outcome = router.popTo(SettingsRoute(), else: showHome)

        #expect(outcome.description == "recovered routeNotInPath by=custom(showHome)")
        let expectedKinds: [NavigationIssue.Kind] = [.routeNotInPath]
        #expect(seen.calls == expectedKinds)
        let expectedPath = [AnyRoute(HomeRoute())]
        #expect(router.state.path == expectedPath)
    }

    @Test("The dismissAll fallback closes every presented flow")
    func dismissAllFallback() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        let outcome = child.popTo(HomeRoute(), else: .dismissAll)

        #expect(outcome.recoveredIssue?.kind == .routeNotInPath)
        #expect(router.presented != nil)
        child.present(HomeRoute())
        #expect(child.popTo(ProductRoute(id: 9), else: .dismissAll).recoveredIssue != nil)
        #expect(child.presented == nil)
    }

    @Test("resetToRoot dismisses everything and pops the root stack")
    func resetToRootDismissesEverythingAndPopsTheRoot() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        let shop = tabs.router(for: .shop)
        shop.push(ProductRoute(id: 1))
        tabs.present(SettingsRoute())
        let sheet = try #require(tabs.presented)

        let outcome = sheet.popTo(HomeRoute(), else: .resetToRoot)

        #expect(outcome.recoveredIssue?.kind == .routeNotInPath)
        #expect(tabs.presented == nil)
        #expect(shop.state.path.isEmpty)
    }

    @Test("A tab fallback pops the selected tab")
    func tabFallbackPopsSelectedTab() {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .shop, configuration: .permissive)
        tabs.router(for: .shop).push(ProductRoute(id: 1))

        let outcome = tabs.select(.profile, else: .popToRoot)

        #expect(outcome.recoveredIssue?.kind == .unknownTab)
        #expect(tabs.router(for: .shop).state.path.isEmpty)
    }

    @Test("A failed step in a transaction uses its fallback")
    func failedStepInTransactionUsesItsFallback() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())

        let outcome = router.transaction {
            $0.push(ProductRoute(id: 1))
            $0.popTo(SettingsRoute(), else: .popToRoot)
            $0.push(ProductRoute(id: 2))
        }

        #expect(outcome.recoveredIssue?.kind == .routeNotInPath)
        let expectedPath = [AnyRoute(ProductRoute(id: 2))]
        #expect(router.state.path == expectedPath)
    }

    @Test("Recovered and failed issues are both reported")
    func recoveredAndFailedIssuesAreReported() {
        let router = StackRouter(configuration: .permissive)
        let reported = Spy<NavigationIssue.Kind, Void>()
        router.tree.onReported { issue in
            reported(issue.kind)
        }

        router.popTo(HomeRoute(), else: .popToRoot)
        router.pop()

        let expectedKinds: [NavigationIssue.Kind] = [.routeNotInPath, .emptyPath]
        #expect(reported.calls == expectedKinds)
    }

    @Test("The strict mode seam sees every outcome")
    func strictModeSeamSeesEveryOutcome() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        router.dismiss()
        let outcomes = Spy<String, Void>()
        router.tree.onFinished { outcome in
            outcomes(outcome.description)
        }

        router.push(HomeRoute())
        router.pop(count: 2)
        router.popTo(SettingsRoute())
        child.push(HomeRoute())

        let expected = ["applied", "recovered notEnoughRoutes by=popToRoot", "failed routeNotInPath", "ignored"]
        #expect(outcomes.calls == expected)
    }

    @Test("Fallbacks describe themselves and compare by name")
    func fallbackDescriptionsAndEquality() {
        let first = NavigationFallback.custom("showHome") { _, _ in }
        let second = NavigationFallback.custom("showHome") { _, _ in }

        #expect(first == second)
        #expect(first.description == "custom(showHome)")
        #expect(NavigationFallback.resetToRoot.description == "resetToRoot")
        #expect(first != .popToRoot)
    }
}
