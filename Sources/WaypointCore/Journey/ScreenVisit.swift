//
//  ScreenVisit.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// One screen the user saw: the screen on display after a change, with where the user came from
/// and how.
///
/// The tree works it out from the routers after each change, across tabs, stacks and
/// presentations, so screens need no code for it. A change that pushes several routes at once
/// makes one visit, to the screen on top. A change that leaves the screen on display as it was,
/// such as a push in another tab, makes none. Read the latest one with
/// ``StackRouter/screenVisit`` or ``TabRouter/screenVisit``.
///
/// ```text
/// 🧭 screen_viewed  Product 3 "Orbit Lamp"   ◀ Product list after 2.1 s · push by app (…:88)
/// ```
///
/// Conformances:
/// - `Sendable`, so a visit can be handed off the main actor, such as to analytics later.
/// - `Equatable`, so tests can compare visits.
public struct ScreenVisit: Sendable, Equatable {
    /// How the screen came on display.
    ///
    /// Conformances:
    /// - `Sendable`, so a visit can be handed off the main actor.
    /// - `Equatable`, so tests can compare visits.
    /// - `CustomStringConvertible`, for the word the journey writes, such as `full screen`.
    public enum Transition: Sendable, Equatable, CustomStringConvertible {
        /// The screen was on display when the stack first appeared.
        case appear
        /// A push.
        case push
        /// A pop, by the app or the user going back.
        case back
        /// The whole path was replaced.
        case set
        /// Another tab was selected.
        case tab
        /// A flow was presented as a sheet.
        case sheet
        /// A flow was presented full screen.
        case fullScreen
        /// The flow above it was dismissed.
        case dismiss

        /// `push`, `back`, `full screen` and so on.
        public var description: String {
            switch self {
            case .appear:
                return "appear"
            case .push:
                return "push"
            case .back:
                return "back"
            case .set:
                return "set"
            case .tab:
                return "tab"
            case .sheet:
                return "sheet"
            case .fullScreen:
                return "full screen"
            case .dismiss:
                return "dismiss"
            }
        }
    }

    /// Who made the change.
    ///
    /// Conformances:
    /// - `Sendable`, so a visit can be handed off the main actor.
    /// - `Equatable`, so tests can compare visits.
    /// - `CustomStringConvertible`, for the words the journey writes, such as `by user`.
    public enum Origin: Sendable, Equatable, CustomStringConvertible {
        /// App code called a router.
        case app
        /// The user changed the screen directly, such as a swipe back.
        case user
        /// A fallback ran because the call that was asked for failed.
        case fallback

        /// `app`, `user` or `fallback`.
        public var description: String {
            switch self {
            case .app:
                return "app"
            case .user:
                return "user"
            case .fallback:
                return "fallback"
            }
        }
    }

    /// The place of a screen in a flow with a fixed number of steps, such as step 2 of 3.
    ///
    /// Conformances:
    /// - `Sendable`, so a visit can be handed off the main actor.
    /// - `Equatable`, so tests can compare visits.
    public struct Step: Sendable, Equatable {
        /// The step, from 1.
        public let number: Int

        /// How many steps the flow has.
        public let count: Int
    }

    /// The screen on display.
    public let screen: ScreenReference

    /// The screen on display before it, or `nil` for the first visit.
    public let previous: ScreenReference?

    /// Where this part of the journey started: the tab, the presented flow's root, the stack's
    /// root, or the nearest screen below that ``TrackableScreen/startsJourney``. It stays the same
    /// while the user drills down.
    public let source: ScreenReference

    /// The screens from the tree's root to this one, such as `Shop › Product list › Product 3`.
    public let journey: [ScreenReference]

    /// How the screen came on display.
    public let transition: Transition

    /// Who made the change.
    public let origin: Origin

    /// The file and line of the call that made the change, such as `ProductListView.swift:88`,
    /// or `nil` when the user made it or the stack first appeared.
    public let callSite: String?

    /// The `trigger:` the call gave, such as `related_products`, or `nil`.
    public let trigger: String?

    /// The screen's step in its flow, when the flow's root gives ``TrackableScreen/stepsInFlow``
    /// and the screen is one of its steps.
    public let step: Step?

    /// How long the previous screen was on display, or `nil` for the first visit.
    public let timeOnPrevious: Duration?

    /// How many screens the journey holds after its first: 2 for
    /// `Shop › Product list › Product 3`.
    public var depth: Int {
        max(journey.count - 1, 0)
    }

    /// The same visit, its screen replaced by `screen`, such as once its view has a name.
    func withScreen(_ screen: ScreenReference) -> ScreenVisit {
        ScreenVisit(
            screen: screen,
            previous: previous,
            source: source,
            journey: journey,
            transition: transition,
            origin: origin,
            callSite: callSite,
            trigger: trigger,
            step: step,
            timeOnPrevious: timeOnPrevious
        )
    }
}

/// A flow presented over another one, with the screen it starts at: the funnel analytics reads
/// from a checkout or a sign-in.
///
/// ```text
/// 🧭 flow_started   Checkout                 from Cart · full screen
/// 🧭 flow_finished  Checkout                 after 42.0 s · by app (CartCoordinator.swift:180)
/// ```
///
/// Conformances:
/// - `Sendable`, so it can be handed off the main actor, such as to analytics later.
/// - `Equatable`, so tests can compare flows.
public struct FlowJourney: Sendable, Equatable {
    /// The presented flow.
    public let flow: FlowID

    /// The flow's first screen, which names it.
    public let screen: ScreenReference

    /// The screen on display when the flow was presented, or `nil` when there was none.
    public let presenter: ScreenReference?

    /// How the flow is presented.
    public let style: PresentationStyle

    /// Who presented the flow, or who dismissed it once it ended.
    public let origin: ScreenVisit.Origin

    /// The file and line of the call that presented or dismissed the flow, or `nil` when the user
    /// dismissed it.
    public let callSite: String?

    /// The `trigger:` the presenting call gave, or `nil`.
    public let trigger: String?

    /// How long the flow was on display, once it ended; `nil` while it is.
    public let duration: Duration?

    /// The same flow, ended after `duration` by `origin`.
    func ended(after duration: Duration, by origin: ScreenVisit.Origin, callSite: String?) -> FlowJourney {
        FlowJourney(
            flow: flow,
            screen: screen,
            presenter: presenter,
            style: style,
            origin: origin,
            callSite: callSite,
            trigger: trigger,
            duration: duration
        )
    }
}
