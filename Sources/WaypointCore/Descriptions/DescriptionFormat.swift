//
//  DescriptionFormat.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Shared pieces of the description format (decision 0010).
enum DescriptionFormat {
    /// Routes as a list, such as `[HomeRoute, ProductRoute(id: <private>)]`.
    static func list(_ routes: [AnyRoute], revealingPrivateValues: Bool) -> String {
        let items = routes.map { route in
            route.debugDescription(revealingPrivateValues: revealingPrivateValues)
        }
        return "[\(items.joined(separator: ", "))]"
    }

    /// A readable name for a tab or root value: its `String` raw value, its case name, or its
    /// type name. Associated values are private, like route fields.
    static func name(of value: some Hashable) -> String {
        if let raw = (value as? any RawRepresentable)?.rawValue as? String {
            return raw
        }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .enum else {
            return "\(type(of: value))"
        }
        return caseName(of: value, mirror: mirror)
    }

    /// `case`, or `case(<private>)` for a case with a payload.
    private static func caseName(of value: some Hashable, mirror: Mirror) -> String {
        guard let payload = mirror.children.first, let label = payload.label else {
            return String(describing: value)
        }
        return "\(label)(\(RouteDescriber.redacted))"
    }
}
