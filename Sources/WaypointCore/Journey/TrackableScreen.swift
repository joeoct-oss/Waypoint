//
//  TrackableScreen.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A route that says how the user's journey names its screen.
///
/// Every route is already named in the journey without this protocol: `ProductRoute` reads as
/// `Product`, with the values of its `publicLogFields` after the name, such as `Product 3`.
/// Conform to change the name, add a display name, or leave a screen out:
///
/// ```swift
/// // Conformances:
/// // - `TrackableScreen`, so the journey shows the product's title next to its id.
/// struct ProductRoute: TrackableScreen {
///     static let publicLogFields: Set<String> = ["id"]
///
///     let id: Int
///     @RouteHint var title: String?
///
///     var screenDisplayName: String? {
///         title
///     }
/// }
/// ```
///
/// The journey writes `screen_viewed  Product 3 "Orbit Lamp"`. A display name is written as it
/// is, so give one only when it holds no user data.
///
/// Conformances:
/// - `Route`, because the journey names the screens that routes show.
public protocol TrackableScreen: Route {
    /// The screen's name in the journey. Default: the type name without `Route`, in words, so
    /// `ProductListRoute` reads `Product list`.
    static var screenName: String { get }

    /// Whether the journey counts this screen. Turn it off for screens that aren't screens to a
    /// person, such as a loading step. Default: `true`.
    static var isTracked: Bool { get }

    /// Whether this screen becomes the source of the screens opened from it, such as a search
    /// screen. Tab roots and the roots of presented flows start a journey on their own. Default:
    /// `false`.
    static var startsJourney: Bool { get }

    /// The number of steps in the flow this screen starts, when it is the root of a presented
    /// flow that has a fixed number of steps, such as a checkout. The journey then writes
    /// `step 2 of 3`. Default: `nil`.
    static var stepsInFlow: Int? { get }

    /// Whether this screen counts as a step of its flow. Turn it off for a screen pushed on the
    /// side of a flow, such as an address form inside a checkout. Default: `true`.
    static var isFlowStep: Bool { get }

    /// A name for this one screen, such as a product's title, written after the screen's name.
    /// Default: `nil`.
    var screenDisplayName: String? { get }
}

extension TrackableScreen {
    /// The type name without `Route`, in words.
    public static var screenName: String {
        RouteDescriber.readableTypeName(routeKey.typeName)
    }

    /// Tracked.
    public static var isTracked: Bool {
        true
    }

    /// Doesn't start a journey.
    public static var startsJourney: Bool {
        false
    }

    /// No fixed number of steps.
    public static var stepsInFlow: Int? {
        nil
    }

    /// A step of its flow.
    public static var isFlowStep: Bool {
        true
    }

    /// No display name.
    public var screenDisplayName: String? {
        nil
    }
}
