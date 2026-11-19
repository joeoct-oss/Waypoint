//
//  ScreenReference.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// One screen as the user's journey names it, such as `Product 3 "Orbit Lamp"`.
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public struct ScreenReference: NavigationRecord {
    /// The screen's name, from ``TrackableScreen/screenName``, the stack's root name or its tab,
    /// such as `Product`.
    public let name: String

    /// The values of the route's `publicLogFields`, or an enum route's case, such as `3`. `nil`
    /// when the route shows none.
    public let detail: String?

    /// The name and the detail, such as `Product 3` or `Checkout step: payment`.
    public let title: String

    /// The screen's ``TrackableScreen/screenDisplayName``, such as `Orbit Lamp`, or `nil`.
    public let displayName: String?

    /// The flow the screen is in.
    public let flow: FlowID

    /// The route the screen shows, or `nil` for a stack's root screen that has no route.
    public let route: AnyRoute?

    /// The name of the view that draws the screen, such as `ProductDetailView`, or `nil` when no
    /// renderer said.
    public let viewName: String?

    /// The name of the coordinator that owns the screen's stack, such as `ProductsCoordinator`,
    /// or `nil` when none was named.
    public let coordinator: String?

    /// The view name, else the title: what the journey box calls the screen.
    public var screenLabel: String {
        viewName ?? title
    }

    /// The title, then the display name in quotes: `Product 3 "Orbit Lamp"`.
    public var description: String {
        guard let displayName else {
            return title
        }
        return "\(title) \"\(displayName)\""
    }

    /// A screen that shows `route` in `flow`.
    init(route: AnyRoute, flow: FlowID, viewName: String? = nil, coordinator: String? = nil) {
        let traits = route.screenTraits
        let detail = RouteDescriber.screenDetail(route.base)
        self.name = traits.name
        self.detail = detail?.text
        self.title = detail.map { "\(traits.name)\($0.separator)\($0.text)" } ?? traits.name
        self.displayName = traits.displayName
        self.flow = flow
        self.route = route
        self.viewName = viewName
        self.coordinator = coordinator
    }

    /// A stack's root screen that has no route, named `name`.
    init(rootNamed name: String, flow: FlowID, viewName: String? = nil, coordinator: String? = nil) {
        self.name = name
        self.detail = nil
        self.title = name
        self.displayName = nil
        self.flow = flow
        self.route = nil
        self.viewName = viewName
        self.coordinator = coordinator
    }

    /// The same description: a screen's name holds only public values and its display name.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        description
    }
}

/// What a route's type says about its screen, with the defaults for a route that isn't a
/// ``TrackableScreen``.
struct ScreenTraits {
    /// The screen's name.
    let name: String

    /// Whether the journey counts the screen.
    let isTracked: Bool

    /// Whether the screen becomes the source of the screens opened from it.
    let startsJourney: Bool

    /// The number of steps in the flow the screen starts, if fixed.
    let stepsInFlow: Int?

    /// Whether the screen counts as a step of its flow.
    let isFlowStep: Bool

    /// A name for this one screen, if any.
    let displayName: String?

    /// The defaults for a route type named `typeName`.
    init(typeName: String) {
        self.init(
            name: RouteDescriber.readableTypeName(typeName),
            isTracked: true,
            startsJourney: false,
            stepsInFlow: nil,
            isFlowStep: true,
            displayName: nil
        )
    }

    /// What a ``TrackableScreen`` says.
    init<Screen: TrackableScreen>(_ screen: Screen) {
        self.init(
            name: Screen.screenName,
            isTracked: Screen.isTracked,
            startsJourney: Screen.startsJourney,
            stepsInFlow: Screen.stepsInFlow,
            isFlowStep: Screen.isFlowStep,
            displayName: screen.screenDisplayName
        )
    }

    /// Traits from every field.
    private init(
        name: String,
        isTracked: Bool,
        startsJourney: Bool,
        stepsInFlow: Int?,
        isFlowStep: Bool,
        displayName: String?
    ) {
        self.name = name
        self.isTracked = isTracked
        self.startsJourney = startsJourney
        self.stepsInFlow = stepsInFlow
        self.isFlowStep = isFlowStep
        self.displayName = displayName
    }
}

extension AnyRoute {
    /// What this route's type says about its screen.
    var screenTraits: ScreenTraits {
        guard let screen = base as? any TrackableScreen else {
            return ScreenTraits(typeName: routeKey.typeName)
        }
        return ScreenTraits(screen)
    }
}
