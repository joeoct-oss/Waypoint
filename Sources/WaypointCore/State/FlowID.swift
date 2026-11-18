//
//  FlowID.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A stable name for one flow in the tree.
///
/// Stays the same across restoration, so events and snapshots can refer to it.
///
/// Conformances:
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events
///   and test failures.
public struct FlowID: NavigationValue, NavigationDescribable {
    /// The flow's name, such as `shop`.
    public let name: String

    /// The name.
    public var description: String {
        name
    }

    /// Names a flow. Its `description` is the name, such as `shop`.
    public init(_ name: String) {
        self.name = name
    }

    /// Decodes a flow saved as its name.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.name = try container.decode(String.self)
    }

    /// Encodes the flow as its name.
    public func encode(to encoder: any Encoder) throws {
        // `var` because `SingleValueEncodingContainer.encode` is mutating.
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }

    /// The name. A flow's name holds no private values.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        name
    }
}
