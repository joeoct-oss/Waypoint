//
//  RouteRegistry.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

/// Maps route keys to route types, so erased routes can be encoded and decoded.
///
/// The root router owns one registry and fills it while destinations are registered, so most
/// apps never touch it. Registering checks every key at once, so mistakes show up on the first
/// launch in development and in tests, before any saved state is read:
///
/// - A former key that belongs to another route reports ``RouteDecodingError/duplicateRouteKey(_:types:)``.
///   The current key wins.
/// - A `private`, `fileprivate` or local route type reports ``RouteDecodingError/unstableRouteKey(_:)``.
///   It works in memory but is not saved.
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

    /// A registered route type and whether the key is its current one.
    private struct Entry: Sendable {
        /// The route type.
        let type: any Route.Type

        /// Whether the key is the type's current key rather than a former one.
        let isCurrent: Bool
    }

    /// Route types by current and former key.
    private var entries: [RouteKey: Entry] = [:]

    /// Problems found while registering, in the order they were found.
    ///
    /// The root router reports each one as an issue when it is found.
    public private(set) var problems: [RouteDecodingError] = []

    /// Every registered route type, once each.
    public var registeredTypes: [any Route.Type] {
        entries.values.filter(\.isCurrent).map(\.type)
    }

    /// Creates an empty registry.
    public init() { }

    /// Encodes a route with its current key, with or without a registry.
    static func encode(_ route: AnyRoute, to encoder: any Encoder) throws {
        let key = route.routeKey
        guard key.isStable else {
            throw RouteDecodingError.unstableRouteKey(key)
        }
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

    /// Registers a route type under its ``Route/routeKey`` and its ``Route/formerRouteKeys``.
    ///
    /// Registering the same type twice does nothing.
    public mutating func register<R: Route>(_ type: R.Type) {
        guard !isRegistered(type) else {
            return
        }
        registerCurrentKey(of: type)
        for former in R.formerRouteKeys {
            registerFormerKey(former, of: type)
        }
    }

    /// Whether this route type is registered under its current key.
    public func isRegistered<R: Route>(_ type: R.Type) -> Bool {
        guard let entry = entries[R.routeKey] else {
            return false
        }
        return entry.isCurrent && entry.type == type
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

    /// Records the type under its current key. A former key of another type that held it loses.
    private mutating func registerCurrentKey<R: Route>(of type: R.Type) {
        let key = R.routeKey
        if !key.isStable {
            problems.append(.unstableRouteKey(key))
        }
        if let existing = entries[key] {
            problems.append(.duplicateRouteKey(key, types: [String(reflecting: existing.type), key.rawValue]))
        }
        entries[key] = Entry(type: type, isCurrent: true)
    }

    /// Records a former key, unless it is malformed or already taken.
    private mutating func registerFormerKey<R: Route>(_ former: RouteKey, of type: R.Type) {
        guard former.isWellFormed else {
            problems.append(.invalidRouteKey(former.rawValue))
            return
        }
        if let existing = entries[former] {
            reportTakenFormerKey(former, existing: existing, claimedBy: type)
            return
        }
        entries[former] = Entry(type: type, isCurrent: false)
    }

    /// Reports a former key that another type already holds, unless it is this type's own.
    private mutating func reportTakenFormerKey<R: Route>(_ former: RouteKey, existing: Entry, claimedBy type: R.Type) {
        guard existing.type != type else {
            return
        }
        problems.append(.duplicateRouteKey(former, types: [String(reflecting: existing.type), R.routeKey.rawValue]))
    }
}

extension CodingUserInfoKey {
    /// Where a decoder finds the ``RouteRegistry`` it needs to decode ``AnyRoute`` values.
    public static let routeRegistry = CodingUserInfoKey(rawValue: "dev.waypoint.routeRegistry")!
}
