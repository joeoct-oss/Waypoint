//
//  NavigationChange.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// One change to the navigation state.
///
/// Routers emit applied changes as events, and tests can compare them.
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in logs.
public enum NavigationChange: NavigationRecord {
    /// Routes were pushed, bottom first.
    case pushed([AnyRoute])
    /// Routes were popped, bottom first.
    case popped([AnyRoute])
    /// The whole path was replaced.
    case replaced(from: [AnyRoute], to: [AnyRoute])
    /// A flow was presented.
    case presented(Presentation)
    /// A presented flow was dismissed, with everything it presented.
    case dismissed(FlowID)
    /// Another tab was selected. Tabs are named by their `String` raw value or case name.
    case tabSelected(from: String, to: String)

    /// One line, such as `pushed [ProductRoute(id: <private>)]` or `tabSelected home -> shop`.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
    }

    /// `name [routes]`.
    private static func routesLine(_ name: String, _ routes: [AnyRoute], _ reveal: Bool) -> String {
        "\(name) \(DescriptionFormat.list(routes, revealingPrivateValues: reveal))"
    }

    /// `replaced [old] -> [new]`.
    private static func replacedLine(_ old: [AnyRoute], _ new: [AnyRoute], _ reveal: Bool) -> String {
        let from = DescriptionFormat.list(old, revealingPrivateValues: reveal)
        let to = DescriptionFormat.list(new, revealingPrivateValues: reveal)
        return "replaced \(from) -> \(to)"
    }

    /// The same line, with route fields revealed when asked.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        switch self {
        case .pushed(let routes):
            return Self.routesLine("pushed", routes, revealingPrivateValues)
        case .popped(let routes):
            return Self.routesLine("popped", routes, revealingPrivateValues)
        case .replaced(let old, let new):
            return Self.replacedLine(old, new, revealingPrivateValues)
        case .presented(let presentation):
            return "presented \(presentation.debugDescription(revealingPrivateValues: revealingPrivateValues))"
        case .dismissed(let flow):
            return "dismissed flow=\(flow)"
        case .tabSelected(let old, let new):
            return "tabSelected \(old) -> \(new)"
        }
    }
}
