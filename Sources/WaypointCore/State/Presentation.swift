//
//  Presentation.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A child flow shown modally above its parent.
///
/// A flow presents at most one child flow at a time. The presented flow can present again, which
/// gives a chain of modals.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct Presentation: Sendable, Equatable, Codable, NavigationDescribable {
    /// How the flow is shown.
    public var style: PresentationStyle

    /// The presented flow.
    public var flow: FlowID

    /// The route of the presented flow's root screen, or `nil` when a coordinator builds the
    /// flow's root itself.
    public var route: AnyRoute?

    /// Describes a presented flow.
    public init(style: PresentationStyle, flow: FlowID, route: AnyRoute? = nil) {
        self.style = style
        self.flow = flow
        self.route = route
    }

    /// `sheet FilterRoute flow=filter`, with the route's fields private.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
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
