//
//  RouteHint.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A value a route carries for its screen's first frame only, such as the product a list already
/// loaded.
///
/// Routes carry identity, and the coordinator supplies the model. A hint lets the screen that
/// was tapped show what the list already has at once, then refresh by id:
///
/// ```swift
/// // Conformances:
/// // - `Route`, so it can be pushed, presented and saved.
/// struct ProductRoute: Route {
///     let id: Product.ID
///
///     @RouteHint
///     var preview: Product?
/// }
///
/// router.push(
///     ProductRoute(
///         id: product.id,
///         preview: product
///     )
/// )
/// ```
///
/// A hint is not part of the route:
///
/// - It is never saved. Encoding writes nothing for it, and decoding, restoring or building the
///   route from a link gives `nil`.
/// - It is never compared. Two routes with the same id are equal and hash the same, whatever
///   their hints hold.
/// - It is never described. Logs, events and test failures leave it out, even when private
///   values are revealed or the field is listed in ``Route/publicLogFields``.
///
/// So the screen must work without it: a link or a restore opens it with `nil`, and it loads by
/// id. The value needs only `Sendable`, not `Hashable` or `Codable`.
///
/// Conformances:
/// - `Sendable`, because routes cross actors.
/// - `Hashable`, so a hinted route still compares and hashes by its identity only.
/// - `Codable`, so a hinted route still saves; the hint itself is never written.
/// - `Value: Sendable`, so a route that holds the hint stays `Sendable`.
@propertyWrapper
public struct RouteHint<Value: Sendable>: Sendable, Hashable, Codable {
    /// The hinted value, or `nil` after saving, restoring or building the route from a link.
    public let wrappedValue: Value?

    /// A hint with this value, or with none.
    public init(wrappedValue: Value?) {
        self.wrappedValue = wrappedValue
    }

    /// An empty hint: whatever was saved, a decoded hint holds nothing.
    public init(from decoder: any Decoder) throws {
        self.init(wrappedValue: nil)
    }

    /// Every hint is equal to every other, so it never changes a route's identity.
    public static func == (lhs: RouteHint, rhs: RouteHint) -> Bool {
        true
    }

    /// Writes `null` when a hint is encoded on its own. Inside a route, the key is left out
    /// entirely.
    public func encode(to encoder: any Encoder) throws {
        // `var` because `SingleValueEncodingContainer.encodeNil()` is mutating.
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }

    /// Adds nothing, so a hint never changes a route's hash.
    public func hash(into hasher: inout Hasher) { }
}

/// A route's hint, which descriptions leave out.
protocol RouteHintField { }

extension RouteHint: RouteHintField { }

extension KeyedEncodingContainer {
    /// Leaves a route's hint out of its saved value, so the key isn't written at all.
    ///
    /// A route's synthesized `encode(to:)` calls this for a hint field instead of the general
    /// `encode(_:forKey:)`, because it is the more specific overload.
    public func encode<Value>(
        _ value: RouteHint<Value>,
        forKey key: Key
    ) throws { }
}

extension KeyedDecodingContainer {
    /// An empty hint, whether or not the saved value or link has the key.
    public func decode<Value>(
        _ type: RouteHint<Value>.Type,
        forKey key: Key
    ) throws -> RouteHint<Value> {
        RouteHint(wrappedValue: nil)
    }
}
