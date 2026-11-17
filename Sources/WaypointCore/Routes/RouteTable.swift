//
//  RouteTable.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A table of destinations keyed by route type.
///
/// `Payload` is whatever the renderer builds for a route: a view, a view controller, or a test
/// value. The renderers fill it from `.destination(_:)` modifiers and coordinators, so lookup is
/// the same code everywhere, and no central `switch` over routes is needed.
public struct RouteTable<Payload> {
    /// Builders by route key.
    private var builders: [RouteKey: (AnyRoute) -> Payload?] = [:]

    /// The route types registered for decoding, filled as destinations are registered.
    public private(set) var registry = RouteRegistry()

    /// Creates an empty table.
    public init() { }

    /// Every registered route type.
    public var registeredTypes: [any Route.Type] {
        registry.registeredTypes
    }

    /// Registers how to build the payload for one route type. Registering a type again replaces
    /// its destination.
    ///
    /// Also registers the type for decoding.
    public mutating func register<R: Route>(_ type: R.Type, _ make: @escaping (R) -> Payload) {
        registry.register(type)
        builders[R.routeKey] = { route in
            route.as(R.self).map(make)
        }
    }

    /// The payload for a route, or `nil` if its type is not registered.
    public func payload(for route: AnyRoute) -> Payload? {
        builders[route.routeKey]?(route)
    }

    /// Whether a destination is registered for this route type.
    public func contains<R: Route>(_ type: R.Type) -> Bool {
        builders[R.routeKey] != nil
    }
}
