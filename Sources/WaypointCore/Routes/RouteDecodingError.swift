//
//  RouteDecodingError.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Why an erased route could not be decoded or registered.
///
/// Every case fails loudly in development and never crashes in release.
///
/// Conformances:
/// - `Error`, so it can be thrown.
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in logs.
public enum RouteDecodingError: Error, NavigationRecord {
    /// No registered route type has this key, current or former.
    case unknownRouteKey(RouteKey)
    /// The key is known, but the saved value no longer decodes as that type, such as a removed
    /// enum case.
    case invalidPayload(RouteKey)
    /// Two route types claim the same key through `formerRouteKeys`. The current key wins.
    case duplicateRouteKey(RouteKey, types: [String])
    /// A `private`, `fileprivate` or local route type: its key changes between builds, so it is
    /// not saved.
    case unstableRouteKey(RouteKey)
    /// A former key that is empty or isn't a module and type name.
    case invalidRouteKey(String)

    /// One line, such as `unknownRouteKey key=Shop.OldProductRoute`.
    public var description: String {
        switch self {
        case .unknownRouteKey(let key):
            return line("unknownRouteKey", key: key.rawValue)
        case .invalidPayload(let key):
            return line("invalidPayload", key: key.rawValue)
        case .duplicateRouteKey(let key, let types):
            return duplicateLine(key: key, types: types)
        case .unstableRouteKey(let key):
            return line("unstableRouteKey", key: key.rawValue)
        case .invalidRouteKey(let rawValue):
            return line("invalidRouteKey", key: "\"\(rawValue)\"")
        }
    }

    /// What went wrong and how to fix it, in one sentence.
    public var message: String {
        switch self {
        case .unknownRouteKey(let key):
            return unknownKeyMessage(key)
        case .invalidPayload(let key):
            return invalidPayloadMessage(key)
        case .duplicateRouteKey(let key, let types):
            return duplicateMessage(key: key, types: types)
        case .unstableRouteKey(let key):
            return unstableMessage(key)
        case .invalidRouteKey(let rawValue):
            return invalidKeyMessage(rawValue)
        }
    }

    /// The line, then the message on an indented second line. Holds no private values.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        "\(description)\n  \(message)"
    }

    /// `name key=value`.
    private func line(_ name: String, key: String) -> String {
        "\(name) key=\(key)"
    }

    /// `duplicateRouteKey key=… types=[A, B]`.
    private func duplicateLine(key: RouteKey, types: [String]) -> String {
        "duplicateRouteKey key=\(key.rawValue) types=[\(types.joined(separator: ", "))]"
    }

    /// Says which line to add when a renamed route lost its old key.
    private func unknownKeyMessage(_ key: RouteKey) -> String {
        "No route type is registered for \(key.rawValue). "
            + "If this route was renamed, add RouteKey(\"\(key.rawValue)\") to the new type's formerRouteKeys."
    }

    /// Explains a saved value that no longer decodes.
    private func invalidPayloadMessage(_ key: RouteKey) -> String {
        "The saved value of \(key.rawValue) no longer decodes as that type, "
            + "for example because a case or field was removed."
    }

    /// Names both types that claim a key.
    private func duplicateMessage(key: RouteKey, types: [String]) -> String {
        "\(types.joined(separator: " and ")) both claim the key \(key.rawValue). "
            + "The type whose current key it is wins. Remove the key from the other type's formerRouteKeys."
    }

    /// Says how to make a route type's key stable.
    private func unstableMessage(_ key: RouteKey) -> String {
        "\(key.typeName) is private, fileprivate or local, so its key changes between builds "
            + "and it is not saved. Make the type internal or wider."
    }

    /// Says what a key must look like.
    private func invalidKeyMessage(_ rawValue: String) -> String {
        "\"\(rawValue)\" is not a route key. A key is a module and type name, such as Shop.ProductRoute."
    }
}
