//
//  ConcurrencyFixtures.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Fixtures for the concurrency tests. Like the tests, they use WaypointCore's public API only.

import Foundation
import WaypointCore

/// Holds a router weakly, for a failure handler or fallback made before the router exists.
@MainActor
final class RouterHolder {
    /// The router, once made.
    weak var router: StackRouter?
}

/// A route whose identifier may be logged, so a test can find each route's log lines.
///
/// Conformances:
/// - `Route`, so it can be pushed, presented and saved.
struct ItemRoute: Route {
    /// Logged unredacted, so each route's lines can be told apart.
    static let publicLogFields: Set<String> = ["id"]

    /// The item's identifier.
    let id: Int

    /// The text a log line holds for this route, such as `id: 7`.
    var logMark: String {
        "id: \(id)"
    }
}

/// A gate a test opens by hand, so work waiting on it runs only after the test has done
/// something else first. It forces an order without sleeping.
actor Gate {
    /// Whether the gate is open. `var` because the test opens it once.
    private var isOpen = false

    /// The work waiting for the gate. `var` because waiters arrive one by one.
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Returns once the gate is open.
    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Opens the gate and lets every waiter go.
    func open() {
        isOpen = true
        let waiting = waiters
        waiters = []
        for waiter in waiting {
            waiter.resume()
        }
    }
}

/// Work an app does off the main actor, such as a service that loads data and then navigates.
actor BackgroundService {
    /// Loads, then pushes `route` by hopping to the main actor.
    func load(then route: ItemRoute, on router: StackRouter) async -> NavigationOutcome {
        await router.push(route)
    }

    /// Encodes a path on this actor.
    func encode(_ path: [AnyRoute]) throws -> Data {
        try JSONEncoder().encode(path)
    }

    /// Decodes a path on this actor, with `registry` in the decoder's user info.
    func decode(_ data: Data, registry: RouteRegistry) throws -> [AnyRoute] {
        let decoder = JSONDecoder()
        decoder.userInfo[.routeRegistry] = registry
        return try decoder.decode([AnyRoute].self, from: data)
    }

    /// Describes a value on this actor.
    func describe(_ value: some NavigationDescribable) -> String {
        value.debugDescription(revealingPrivateValues: false)
    }

    /// Returns a value after it crossed into this actor and back.
    func roundTrip<Value: Sendable>(_ value: Value) -> Value {
        value
    }

    /// Builds a configuration on this actor: a strict registry with `ItemRoute`, debug logs in
    /// the structured format to `handler`, and a queue limit of 8.
    func makeConfiguration(handler: any LogHandler) -> NavigationConfiguration {
        let registry = RouteRegistry().registering(ItemRoute.self)
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        return NavigationConfiguration(logging: logging, maxQueuedChanges: 8, registry: registry)
    }

    /// Builds a fallback policy on this actor that pops to root when a route isn't in the path.
    func makePolicy() -> FallbackPolicy {
        FallbackPolicy().withFallback(.popToRoot, for: .routeNotInPath)
    }
}
