//
//  RouteKey.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The stable name of a route type, used when a route is saved, decoded or logged.
///
/// A route type's key is its module and type name, such as `Shop.ProductRoute`, so two routes
/// can't share a key. The only place an app writes a key is a renamed route's
/// ``Route/formerRouteKeys``.
///
/// `RouteKey` is not `ExpressibleByStringLiteral`, so a key is never mixed up with another string.
///
/// Conformances:
/// - `NavigationValue`, so the registry can look up a route type by its key, saved state stores
///   the key as a plain string, and keys can leave the main actor in events, logs and snapshots.
/// - `NavigationDescribable`, so logs and test failures print it in the shared format.
public struct RouteKey: NavigationValue, NavigationDescribable {
    /// The full key, such as `Shop.ProductRoute`.
    public let rawValue: String

    /// The key without its module, such as `ProductRoute`. Logs print this.
    ///
    /// A private or local type prints its own name only, without the unstable context.
    public var typeName: String {
        let name = Self.removingUnknownContexts(from: rawValue)
        let generics = name.firstIndex(of: "<") ?? name.endIndex
        guard let dot = name[..<generics].firstIndex(of: ".") else {
            return name
        }
        return String(name[name.index(after: dot)...])
    }

    /// The full key.
    public var description: String {
        rawValue
    }

    /// Whether the key stays the same between builds.
    ///
    /// `private`, `fileprivate` and local types have a memory address in their name.
    var isStable: Bool {
        !rawValue.contains("(unknown context at")
    }

    /// Whether the key has the shape of a module and type name, such as `Shop.ProductRoute`.
    var isWellFormed: Bool {
        let hasSpace = rawValue.contains { $0.isWhitespace }
        let hasModule = rawValue.contains(".")
        let hasEmptyPart = rawValue.hasPrefix(".") || rawValue.hasSuffix(".") || rawValue.contains("..")
        return !rawValue.isEmpty && hasModule && !hasSpace && !hasEmptyPart
    }

    /// The key of a route type: its module and type name, such as `Shop.ProductRoute`.
    public init<R: Route>(_ type: R.Type) {
        self.rawValue = String(reflecting: type)
    }

    /// A key written out, for ``Route/formerRouteKeys`` only.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Decodes a key saved as a plain string.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    /// The name with every `(unknown context at $…).` part removed.
    private static func removingUnknownContexts(from name: String) -> String {
        guard let start = name.range(of: "(unknown context at "),
            let end = name[start.upperBound...].range(of: ").")
        else {
            return name
        }
        return removingUnknownContexts(from: String(name[..<start.lowerBound] + name[end.upperBound...]))
    }

    /// Encodes the key as a plain string.
    public func encode(to encoder: any Encoder) throws {
        // `var` because `SingleValueEncodingContainer.encode` is mutating.
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The full key. A key holds no private values.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        rawValue
    }
}
