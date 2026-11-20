//
//  BackgroundNavigationTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointCore
import WaypointTestSupport

/// P4, P5 and P13: background work navigates by awaiting the main actor, and nothing is lost.
@Suite("Navigating from background work")
@MainActor
struct BackgroundNavigationTests {
    /// How many tasks navigate at once.
    private static let taskCount = 100

    @Test
    func backgroundTaskNavigationLandsOnScreen() async {
        let router = StackRouter(configuration: .permissive)
        let route = ItemRoute(id: 1)

        let outcome = await Task.detached {
            await router.push(route)
        }.value

        let expected = [AnyRoute(route)]
        #expect(outcome == .applied)
        #expect(router.state.path == expected)
    }

    @Test
    func customActorNavigationLandsOnScreen() async {
        let router = StackRouter(configuration: .permissive)
        let route = ItemRoute(id: 1)
        let service = BackgroundService()

        let outcome = await service.load(then: route, on: router)

        let expected = [AnyRoute(route)]
        #expect(outcome == .applied)
        #expect(router.state.path == expected)
    }

    @Test
    func concurrentPushesFromManyTasksAllLandOnce() async {
        let router = StackRouter(configuration: .permissive)
        let routes = (0..<Self.taskCount).map { id in
            ItemRoute(id: id)
        }

        let outcomes = await pushConcurrently(routes, on: router)

        let landed = Dictionary(grouping: router.state.path) { $0 }.mapValues(\.count)
        let expected = Dictionary(uniqueKeysWithValues: routes.map { (AnyRoute($0), 1) })
        #expect(landed == expected)
        #expect(outcomes.allSatisfy { $0 == .applied })
    }

    @Test
    func logHandlerReceivesALineForEachRouteWhileTasksNavigate() async {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        let routes = (0..<Self.taskCount).map { id in
            ItemRoute(id: id)
        }

        _ = await pushConcurrently(routes, on: router)

        let texts = handler.texts
        let unlogged = routes.filter { route in
            !texts.contains { $0.contains(route.logMark) }
        }
        #expect(unlogged.isEmpty)
    }

    /// Pushes each route from its own task, all at once, and returns their outcomes.
    private func pushConcurrently(_ routes: [ItemRoute], on router: StackRouter) async -> [NavigationOutcome] {
        await withTaskGroup(of: NavigationOutcome.self) { group in
            for route in routes {
                group.addTask {
                    await router.push(route)
                }
            }
            var outcomes: [NavigationOutcome] = []
            for await outcome in group {
                outcomes.append(outcome)
            }
            return outcomes
        }
    }
}
