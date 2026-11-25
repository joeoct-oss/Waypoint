//
//  CrossActorValueTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointCore
import WaypointTestSupport

/// P2, P3, P22 and P23: values that describe navigation can go anywhere.
@Suite("Values across actors")
@MainActor
struct CrossActorValueTests {
    /// Each kind of navigation value an app sends off the main actor.
    ///
    /// Conformances:
    /// - `CaseIterable` and `Sendable`, so a test runs once for each.
    enum ValueKind: CaseIterable, Sendable {
        case route
        case stackState
        case tabState
        case presentation
        case tree
        case outcome
        case issue
        case change
        case screenVisit
    }

    @Test("Navigation values cross actors unchanged", arguments: ValueKind.allCases)
    func navigationValuesCrossActorsUnchanged(_ kind: ValueKind) async throws {
        let service = BackgroundService()

        let crossed = try await crossesUnchanged(kind, through: service)

        #expect(crossed)
    }

    @Test("A path encoded on a background actor restores the same screens")
    func stackPathEncodedOnBackgroundActorRestoresTheSameScreens() async throws {
        let configuration = NavigationConfiguration(registry: RouteRegistry().registering(ItemRoute.self))
        let router = StackRouter(configuration: configuration)
        router.push {
            ItemRoute(id: 1)
            ItemRoute(id: 2)
        }
        let service = BackgroundService()

        let data = try await service.encode(router.state.path)
        let decoded = try await service.decode(data, registry: router.registry)
        let restored = StackRouter(configuration: configuration)
        restored.setPath {
            for route in decoded {
                route
            }
        }

        #expect(restored.state.path == router.state.path)
    }

    @Test("Route descriptions read off the main actor match the main actor's")
    func routeDescriptionsReadOnBackgroundActorMatchMain() async {
        let route = AnyRoute(ItemRoute(id: 7))
        let onMain = route.debugDescription(revealingPrivateValues: false)
        let service = BackgroundService()

        let offMain = await service.describe(route)

        #expect(offMain == onMain)
    }

    @Test("A configuration built on a background actor works on the main actor")
    func configurationBuiltOnBackgroundActorWorksOnMain() async {
        let handler = RecordingLogHandler()
        let service = BackgroundService()

        let configuration = await service.makeConfiguration(handler: handler)
        let policy = await service.makePolicy()
        let router = StackRouter(configuration: configuration)
        let pushed = router.push(ItemRoute(id: 1))
        let unregistered = router.push(HomeRoute())

        #expect(pushed == .applied)
        #expect(unregistered.failure?.issue.kind == .unregisteredRoute)
        #expect(router.configuration.maxQueuedChanges == 8)
        #expect(!handler.messages.isEmpty)
        #expect(policy[.routeNotInPath] == .popToRoot)
    }

    /// Whether a value of `kind`, made on the main actor, comes back from `service` equal.
    private func crossesUnchanged(_ kind: ValueKind, through service: BackgroundService) async throws -> Bool {
        switch kind {
        case .route:
            let route = AnyRoute(ItemRoute(id: 1))
            return await service.roundTrip(route) == route
        case .stackState:
            let state = try madeState()
            return await service.roundTrip(state) == state
        case .tabState:
            let state = TabState(tabs: MainTab.homeAndShop, selection: MainTab.shop)
            return await service.roundTrip(state) == state
        case .presentation:
            let presentation = Presentation(style: .sheet, flow: FlowID("checkout"), route: AnyRoute(CartRoute()))
            return await service.roundTrip(presentation) == presentation
        case .tree:
            let tree = NavigationTree(root: .stack(FlowID("main"), try madeState()))
            return await service.roundTrip(tree) == tree
        case .outcome:
            let outcome = StackRouter(configuration: .permissive).pop()
            return await service.roundTrip(outcome) == outcome
        case .issue:
            let issue = try #require(StackRouter(configuration: .permissive).pop().failure?.issue)
            return await service.roundTrip(issue) == issue
        case .change:
            let routes = [AnyRoute(ItemRoute(id: 1))]
            let change = NavigationChange.pushed(routes)
            return await service.roundTrip(change) == change
        case .screenVisit:
            let router = StackRouter(configuration: .permissive)
            router.push(ItemRoute(id: 1))
            let visit = try #require(router.screenVisit)
            return await service.roundTrip(visit) == visit
        }
    }

    /// A stack state made by a real router: two routes and a presented flow.
    private func madeState() throws -> StackState {
        let router = StackRouter(configuration: .permissive)
        router.push(ItemRoute(id: 1))
        router.present(CartRoute())
        return router.state
    }
}
