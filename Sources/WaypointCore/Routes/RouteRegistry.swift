//
//  RouteRegistry.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

/// Maps route keys to route types, so erased routes can be encoded and decoded.
///
/// The root router owns one registry and fills it while destinations are registered, so most
/// apps never touch it.
///
/// A registry is strict unless it was made with ``permissive``: pushing or presenting a route
/// type that isn't registered fails with `unregisteredRoute` and runs its fallback, even when
/// nothing is registered yet. The mode is chosen once and never changes by itself. Tests and
/// previews that push routes without destinations ask for a permissive registry by name:
///
/// ```swift
/// let router = StackRouter(configuration: NavigationConfiguration(registry: .permissive))
/// ``` Registering checks every key at once, so mistakes show up on the first
/// launch in development and in tests, before any saved state is read:
///
/// - A former key that belongs to another route reports
///   ``RouteDecodingError/duplicateRouteKey(_:types:)``. The current key wins.
/// - A `private`, `fileprivate` or local route type reports
///   ``RouteDecodingError/unstableRouteKey(_:)``. It works in memory but is not saved.
/// - An empty or malformed former key reports ``RouteDecodingError/invalidRouteKey(_:)``.
///
/// To decode navigation state, put the registry in the decoder's `userInfo`:
///
/// ```swift
/// let decoder = JSONDecoder()
/// decoder.userInfo[.routeRegistry] = registry
/// let state = try decoder.decode(StackState.self, from: data)
/// ```
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct RouteRegistry: Sendable {
    /// The keys used when a route is saved.
    private enum CodingKeys: String, CodingKey {
        case route
        case value
    }

    /// Whether a route type must be registered before it can be shown.
    ///
    /// Conformances:
    /// - `Sendable`, so a registry that holds it can be shared with the whole tree.
    public enum Mode: Sendable {
        /// Only registered route types can be pushed or presented. The default.
        case strict
        /// Any route can be pushed or presented, for tests and previews without destinations.
        case permissive
    }

    /// A registered route type and whether the key is its current one.
    private struct Entry: Sendable {
        /// The route type.
        let type: any Route.Type

        /// Whether the key is the type's current key rather than a former one.
        let isCurrent: Bool
    }

    /// An empty registry that shows only registered route types. The default.
    public static var strict: RouteRegistry {
        RouteRegistry()
    }

    /// An empty registry that lets any route be shown, for tests and previews. Registered types
    /// are still used for decoding.
    public static var permissive: RouteRegistry {
        RouteRegistry(mode: .permissive)
    }

    /// Route types by current and former key.
    private let entries: [RouteKey: Entry]

    /// Whether a route type must be registered before it can be shown. Chosen when the registry
    /// is made; registering never changes it.
    public let mode: Mode

    /// Problems found while registering, in the order they were found.
    ///
    /// The root router reports each one as an issue when it is found.
    public let problems: [RouteDecodingError]

    /// Every registered route type, once each.
    public var registeredTypes: [any Route.Type] {
        entries.values.filter(\.isCurrent).map(\.type)
    }

    /// Creates an empty registry. Default: strict.
    public init(mode: Mode = .strict) {
        let noEntries: [RouteKey: Entry] = [:]
        let noProblems: [RouteDecodingError] = []
        self.init(entries: noEntries, mode: mode, problems: noProblems)
    }

    /// A registry with these entries, mode and problems.
    private init(entries: [RouteKey: Entry], mode: Mode, problems: [RouteDecodingError]) {
        self.entries = entries
        self.mode = mode
        self.problems = problems
    }

    /// Encodes a route with its current key, with or without a registry.
    static func encode(_ route: AnyRoute, to encoder: any Encoder) throws {
        let key = route.routeKey
        guard key.isStable else {
            throw RouteDecodingError.unstableRouteKey(key)
        }
        // `var` because `KeyedEncodingContainer.encode` is mutating.
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .route)
        try encodeValue(route.base, into: &container)
    }

    /// The registry in a decoder's `userInfo`, or a decoding error that says how to provide one.
    static func required(by decoder: any Decoder) throws -> RouteRegistry {
        guard let registry = decoder.userInfo[.routeRegistry] as? RouteRegistry else {
            let context = DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Decoding a route needs a RouteRegistry in decoder.userInfo[.routeRegistry]."
            )
            throw DecodingError.dataCorrupted(context)
        }
        return registry
    }

    /// Encodes the route's own value under `value`.
    private static func encodeValue<R: Route>(
        _ route: R,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        try container.encode(route, forKey: .value)
    }

    /// Decodes the value under `value` as `R`.
    private static func decodeValue<R: Route>(
        of type: R.Type,
        key: RouteKey,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> AnyRoute {
        do {
            return AnyRoute(try container.decode(R.self, forKey: .value))
        } catch {
            throw RouteDecodingError.invalidPayload(key)
        }
    }

    /// The same registry with a route type added under its ``Route/routeKey`` and its
    /// ``Route/formerRouteKeys``.
    ///
    /// Registering the same type twice returns the registry unchanged.
    public func registering<R: Route>(_ type: R.Type) -> RouteRegistry {
        guard !isRegistered(type) else {
            return self
        }
        return R.formerRouteKeys.reduce(withCurrentKey(of: type)) { registry, former in
            registry.withFormerKey(former, of: type)
        }
    }

    /// Whether this route type is registered under its current key.
    public func isRegistered<R: Route>(_ type: R.Type) -> Bool {
        guard let entry = entries[R.routeKey] else {
            return false
        }
        return entry.isCurrent && entry.type == type
    }

    /// Whether a route may be pushed or presented: any route in a permissive registry, and only
    /// a registered type in a strict one.
    public func allows(_ route: AnyRoute) -> Bool {
        mode == .permissive || type(for: route.routeKey) != nil
    }

    /// The route type for a current or former key.
    public func type(for key: RouteKey) -> (any Route.Type)? {
        entries[key]?.type
    }

    /// Encodes a route with its current key.
    public func encode(_ route: AnyRoute, to encoder: any Encoder) throws {
        try Self.encode(route, to: encoder)
    }

    /// Decodes a route by its key, or throws ``RouteDecodingError``.
    public func decode(from decoder: any Decoder) throws -> AnyRoute {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(RouteKey.self, forKey: .route)
        guard let entry = entries[key] else {
            throw RouteDecodingError.unknownRouteKey(key)
        }
        return try Self.decodeValue(of: entry.type, key: key, from: container)
    }

    /// The registry with the type under its current key. A former key of another type that
    /// held it loses.
    private func withCurrentKey<R: Route>(of type: R.Type) -> RouteRegistry {
        let key = R.routeKey
        let unstable: [RouteDecodingError] = key.isStable ? [] : [.unstableRouteKey(key)]
        let duplicate: [RouteDecodingError] =
            entries[key].map { existing in
                let types = [String(reflecting: existing.type), key.rawValue]
                return [.duplicateRouteKey(key, types: types)]
            } ?? []
        let added = [key: Entry(type: type, isCurrent: true)]
        return RouteRegistry(
            entries: entries.merging(added) { _, new in new },
            mode: mode,
            problems: problems + unstable + duplicate
        )
    }

    /// The registry with a former key, unless it is malformed or already taken.
    private func withFormerKey<R: Route>(_ former: RouteKey, of type: R.Type) -> RouteRegistry {
        guard former.isWellFormed else {
            let invalid: [RouteDecodingError] = [.invalidRouteKey(former.rawValue)]
            return RouteRegistry(entries: entries, mode: mode, problems: problems + invalid)
        }
        if let existing = entries[former] {
            let taken = takenFormerKeyProblems(former, existing, type)
            return RouteRegistry(entries: entries, mode: mode, problems: problems + taken)
        }
        let added = [former: Entry(type: type, isCurrent: false)]
        return RouteRegistry(
            entries: entries.merging(added) { _, new in new },
            mode: mode,
            problems: problems
        )
    }

    /// A problem for a former key that another type already holds, unless it is this type's own.
    private func takenFormerKeyProblems<R: Route>(
        _ former: RouteKey,
        _ existing: Entry,
        _ type: R.Type
    ) -> [RouteDecodingError] {
        guard existing.type != type else {
            return []
        }
        let types = [String(reflecting: existing.type), R.routeKey.rawValue]
        return [.duplicateRouteKey(former, types: types)]
    }
}

extension CodingUserInfoKey {
    /// Where a decoder finds the ``RouteRegistry`` it needs to decode ``AnyRoute`` values.
    public static let routeRegistry = CodingUserInfoKey(rawValue: "dev.waypoint.routeRegistry")!
}
