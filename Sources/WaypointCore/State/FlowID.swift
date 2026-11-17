//
//  FlowID.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A stable name for one flow in the tree.
///
/// Stays the same across restoration, so events and snapshots can refer to it.
///
/// Conformances:
/// - `Hashable`, to find flows in the tree and key dictionaries by flow.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct FlowID: Hashable, Codable, Sendable, NavigationDescribable {
    /// The flow's name, such as `shop`.
    public let name: String

    /// Names a flow. Its `description` is the name, such as `shop`.
    public init(_ name: String) {
        self.name = name
    }

    /// Decodes a flow saved as its name.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.name = try container.decode(String.self)
    }

    /// The name.
    public var description: String {
        name
    }

    /// Encodes the flow as its name.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }

    /// The name. A flow's name holds no private values.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        name
    }
}
