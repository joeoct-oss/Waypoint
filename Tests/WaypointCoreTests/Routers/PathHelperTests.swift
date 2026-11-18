//
//  PathHelperTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Path builders and the helpers that search the path (#47).
@Suite("Path helpers")
@MainActor
struct PathHelperTests {
    @Test
    func pathBuilderSupportsIfAndForIn() {
        let router = StackRouter(configuration: .permissive)
        let showSettings = true
        let showHome = false

        router.setPath {
            HomeRoute()
            for id in 1...3 {
                ProductRoute(id: id)
            }
            if showSettings {
                SettingsRoute()
            }
            if showHome {
                HomeRoute()
            } else {
                WizardStep.review
            }
            AnyRoute(WizardStep.payment)
        }

        let expected: [AnyRoute] = [
            AnyRoute(HomeRoute()),
            AnyRoute(ProductRoute(id: 1)),
            AnyRoute(ProductRoute(id: 2)),
            AnyRoute(ProductRoute(id: 3)),
            AnyRoute(SettingsRoute()),
            AnyRoute(WizardStep.review),
            AnyRoute(WizardStep.payment),
        ]
        #expect(router.state.path == expected)
    }

    @Test
    func pushManyIsOneChange() {
        let router = StackRouter(configuration: .permissive)
        let changes = Recorder<AppliedChange>()
        router.tree.onApplied { applied in
            changes.record(contentsOf: applied)
        }

        router.push {
            HomeRoute()
            ProductRoute(id: 1)
        }

        let pushed = [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 1))]
        let expectedChanges: [NavigationChange] = [.pushed(pushed)]
        #expect(changes.values.map(\.change) == expectedChanges)
    }

    @Test
    func setPathReplacesAndReportsReplaced() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())

        #expect(router.setPath { ProductRoute(id: 1) } == .applied)
        #expect(router.setPath { ProductRoute(id: 1) } == .alreadyThere)
        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test
    func typedPopToFindsLastOfType() {
        let router = StackRouter(configuration: .permissive)
        router.setPath {
            ProductRoute(id: 1)
            ProductRoute(id: 2)
            SettingsRoute()
            HomeRoute()
        }

        #expect(router.popTo(ProductRoute.self) == .applied)
        #expect(router.last(ProductRoute.self) == ProductRoute(id: 2))
        #expect(router.state.path.count == 2)
    }

    @Test
    func typedPopToUsesPredicate() {
        let router = StackRouter(configuration: .permissive)
        router.setPath {
            ProductRoute(id: 1)
            ProductRoute(id: 2)
            HomeRoute()
        }

        router.popTo(ProductRoute.self) { route in
            route.id == 1
        }

        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test
    func typedPopToMissingTypeFails() {
        let router = StackRouter(configuration: .permissive)
        router.push(HomeRoute())

        let outcome = router.popTo(SettingsRoute.self)

        #expect(outcome.failure?.issue.kind == .routeNotInPath)
        #expect(outcome.failure?.issue.message.hasPrefix("No SettingsRoute in the path") == true)
    }

    @Test
    func typedPopToRootScreenPopsToRoot() {
        let router = StackRouter(root: HomeRoute(), configuration: .permissive)
        router.push(ProductRoute(id: 1))

        #expect(router.popTo(HomeRoute.self) == .applied)
        #expect(router.state.path.isEmpty)
    }

    @Test
    func containsAndLast() {
        let router = StackRouter(configuration: .permissive)
        router.setPath {
            ProductRoute(id: 1)
            HomeRoute()
            ProductRoute(id: 2)
        }

        #expect(router.contains(ProductRoute(id: 1)))
        #expect(!router.contains(ProductRoute(id: 3)))
        #expect(router.last(ProductRoute.self) == ProductRoute(id: 2))
        #expect(router.last(SettingsRoute.self) == nil)
    }
}
