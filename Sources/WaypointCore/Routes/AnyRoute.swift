//
//  AnyRoute.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A route of any type, with its stable key.
///
/// Routers, state, events and snapshots hold routes of many types, so they store them as
/// `AnyRoute`. Every public navigation method is generic, so app code works with its own types
/// and rarely sees `AnyRoute`.
///
/// Two erased routes are equal only when they have the same type and equal values.
///
/// It encodes as its key and its value. Decoding needs a ``RouteRegistry`` in the decoder's
/// `userInfo` under ``Foundation/CodingUserInfoKey/routeRegistry``, because the key alone doesn't
/// name a type.
///
/// Conformances:
/// - `Hashable`, so paths can be compared and searched.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Codable`, so navigation state that holds it can be saved and restored.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct AnyRoute: Hashable, Sendable, Codable, NavigationDescribable {
    /// The wrapped route.
    package let base: any Route

    /// The wrapped route's key.
    public var routeKey: RouteKey {
        type(of: base).routeKey
    }

    /// The route's type name and its fields, private by default, such as
    /// `ProductRoute(id: <private>)`.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
    }

    /// Wraps a route.
    public init<R: Route>(_ route: R) {
        self.base = route
    }

    /// Decodes a route by its key, through the registry in the decoder's `userInfo`.
    public init(from decoder: any Decoder) throws {
        let registry = try RouteRegistry.required(by: decoder)
        self = try registry.decode(from: decoder)
    }

    /// Whether two erased routes have the same type and equal values.
    public static func == (lhs: AnyRoute, rhs: AnyRoute) -> Bool {
        lhs.base.isEqual(to: rhs.base)
    }

    /// Hashes the key and the value.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(routeKey)
        hasher.combine(base)
    }

    /// The wrapped route as `R`, or `nil` if it is another type.
    public func `as`<R: Route>(_ type: R.Type) -> R? {
        base as? R
    }

    /// Whether the wrapped route is of type `R`.
    public func `is`<R: Route>(_ type: R.Type) -> Bool {
        base is R
    }

    /// Encodes the route with its current key.
    ///
    /// Throws ``RouteDecodingError/unstableRouteKey(_:)`` for a `private`, `fileprivate` or local
    /// route type, whose key changes between builds.
    public func encode(to encoder: any Encoder) throws {
        try RouteRegistry.encode(self, to: encoder)
    }

    /// The route's type name and fields. Field values show only when revealed or public.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        RouteDescriber.describe(base, revealingPrivateValues: revealingPrivateValues)
    }
}
