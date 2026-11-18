//
//  Presentation.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A child flow shown modally above its parent.
///
/// A flow presents at most one child flow at a time. The presented flow can present again, which
/// gives a chain of modals.
///
/// Conformances:
/// - `NavigationStateValue`, so it can be saved and restored, compared, sent off the main actor and
///   described in logs.
public struct Presentation: NavigationStateValue {
    /// How the flow is shown.
    public let style: PresentationStyle

    /// The presented flow.
    public let flow: FlowID

    /// The route of the presented flow's root screen, or `nil` when a coordinator builds the
    /// flow's root itself.
    public let route: AnyRoute?

    /// `sheet FilterRoute flow=filter`, with the route's fields private.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
    }

    /// Describes a presented flow.
    public init(style: PresentationStyle, flow: FlowID, route: AnyRoute? = nil) {
        self.style = style
        self.flow = flow
        self.route = route
    }

    /// The style, the root route if any, and the flow.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        guard let route else {
            return "\(style) flow=\(flow)"
        }
        let routeText = route.debugDescription(revealingPrivateValues: revealingPrivateValues)
        return "\(style) \(routeText) flow=\(flow)"
    }
}
