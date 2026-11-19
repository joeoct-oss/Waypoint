//
//  JourneyTracker.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// One thing the journey writes after a change.
enum JourneyEntry: Equatable {
    /// A flow was presented.
    case flowStarted(FlowJourney)
    /// A presented flow was dismissed. `cancelled` when the user dismissed it.
    case flowEnded(FlowJourney, cancelled: Bool)
    /// Another tab was selected: its name, and the name of the tab before it.
    case tabSelected(String, from: String, trigger: String?)
    /// Another screen came on display. `showsSource` when its source differs from the last
    /// visit's, or it is the first visit.
    case screenViewed(ScreenVisit, showsSource: Bool)
    /// The same screen came on display again soon after the last time.
    case duplicate(ScreenReference, interval: Duration, callSite: String?)
}

/// What one change was, for the tracker: the changes, the call's trigger and call site, and when.
struct JourneyChange {
    /// The changes the transaction committed, empty when a stack first appeared.
    let changes: [AppliedChange]

    /// The `trigger:` the call gave, if any.
    let trigger: String?

    /// The call's file and line.
    let callSite: String?

    /// When the change was committed, on the tree's clock.
    let time: Duration

    /// How soon a screen may come back before it is reported as a duplicate.
    let duplicateWindow: Duration
}

/// Follows the screen on display across a tree's changes, and says what the journey writes for
/// each change: visits, tab switches, flows started and ended, and duplicates.
@MainActor
final class JourneyTracker {
    /// A presented flow still on display, and when it started.
    private struct OpenFlow {
        /// The flow as it started.
        let journey: FlowJourney

        /// When it started, on the tree's clock.
        let start: Duration
    }

    /// The latest visit, or `nil` before the first.
    ///
    /// `var` because each visit replaces it. Only ``track(_:in:)`` changes it.
    private(set) var visit: ScreenVisit?

    /// What makes the screen of the latest visit the same one, and when it came on display.
    ///
    /// `var` because each visit replaces it. Only ``track(_:in:)`` changes it.
    private var shown: (key: VisibleScreen.Key, since: Duration)?

    /// When each screen last came on display, by flow and route, for the duplicate warning.
    ///
    /// `var` because each visit updates it. Only ``track(_:in:)`` changes it.
    private var lastSeen: [DuplicateKey: Duration] = [:]

    /// The presented flows still on display, by flow.
    ///
    /// `var` because flows start and end. Only ``track(_:in:)`` changes it.
    private var openFlows: [FlowID: OpenFlow] = [:]

    /// What the journey writes for `change` in the tree that `root` starts, in order: ended
    /// flows, the tab switch, started flows, then the visit and its duplicate warning.
    func track(_ change: JourneyChange, in root: any TreeNode) -> [JourneyEntry] {
        let ended = endFlows(change, in: root)
        let tabs = change.changes.compactMap { applied in
            Self.tabEntry(applied, trigger: change.trigger)
        }
        let started = startFlows(change, in: root)
        let visited = visitScreen(change, in: root)
        return ended + tabs + started + visited
    }

    /// The `tabSelected` entry of a tab change, if it is one.
    private static func tabEntry(_ applied: AppliedChange, trigger: String?) -> JourneyEntry? {
        guard case .tabSelected(let old, let new) = applied.change else {
            return nil
        }
        return .tabSelected(VisibleScreen.words(new), from: VisibleScreen.words(old), trigger: trigger)
    }

    /// The origin a visit or a flow writes for a change's origin.
    private static func origin(_ origin: ChangeOrigin) -> ScreenVisit.Origin {
        switch origin {
        case .app:
            return .app
        case .user:
            return .user
        case .fallback:
            return .fallback
        }
    }

    /// How the screen on display came there, from the change that says most about it, and who
    /// made it. `appear` for no change.
    private static func transition(of changes: [AppliedChange]) -> (ScreenVisit.Transition, ChangeOrigin) {
        let ranked = changes.map { applied in
            (transition(of: applied.change), applied.origin)
        }
        let best = ranked.min { first, second in
            rank(first.0) < rank(second.0)
        }
        return best ?? (.appear, .app)
    }

    /// How one change brings a screen on display.
    private static func transition(of change: NavigationChange) -> ScreenVisit.Transition {
        switch change {
        case .presented(let presentation):
            return presentation.style.isFullScreenCover ? .fullScreen : .sheet
        case .dismissed:
            return .dismiss
        case .tabSelected:
            return .tab
        case .popped:
            return .back
        case .pushed:
            return .push
        case .replaced:
            return .set
        }
    }

    /// Which transition wins when one transaction makes several changes: a presentation covers
    /// everything, then a dismissal, a tab switch, a pop, a push and a replaced path.
    private static func rank(_ transition: ScreenVisit.Transition) -> Int {
        let order: [ScreenVisit.Transition] = [.sheet, .fullScreen, .dismiss, .tab, .back, .push, .set, .appear]
        return order.firstIndex(of: transition) ?? order.count
    }

    /// Whether a transition brings a screen forward, so seeing it again soon is a duplicate.
    /// Going back to a screen is not.
    private static func isForward(_ transition: ScreenVisit.Transition) -> Bool {
        switch transition {
        case .push, .set, .tab, .sheet, .fullScreen:
            return true
        case .appear, .back, .dismiss:
            return false
        }
    }

    /// The call site to write for a change: none when the user made it.
    private static func callSite(_ change: JourneyChange, origin: ChangeOrigin) -> String? {
        origin == .user ? nil : change.callSite
    }

    /// Ends every open flow that left the tree, deepest first.
    private func endFlows(_ change: JourneyChange, in root: any TreeNode) -> [JourneyEntry] {
        let gone = openFlows.filter { flow, _ in
            root.node(for: flow) == nil
        }
        let dismissal = change.changes.first { applied in
            guard case .dismissed = applied.change else {
                return false
            }
            return true
        }
        let origin = dismissal?.origin ?? .app
        let site = Self.callSite(change, origin: origin)
        let latestFirst = gone.values.sorted { first, second in
            first.start > second.start
        }
        for open in latestFirst {
            openFlows[open.journey.flow] = nil
        }
        return latestFirst.map { open in
            let ended = open.journey.ended(after: change.time - open.start, by: Self.origin(origin), callSite: site)
            return .flowEnded(ended, cancelled: origin == .user)
        }
    }

    /// Starts a flow for each presentation the change made that is still in the tree.
    private func startFlows(_ change: JourneyChange, in root: any TreeNode) -> [JourneyEntry] {
        change.changes.compactMap { applied in
            guard case .presented(let presentation) = applied.change, root.node(for: presentation.flow) != nil else {
                return nil
            }
            return startFlow(presentation, applied.origin, change)
        }
    }

    /// Starts one presented flow, from the screen on display before it.
    private func startFlow(_ presentation: Presentation, _ origin: ChangeOrigin, _ change: JourneyChange) -> JourneyEntry {
        let screen = presentation.route.map { route in
            ScreenReference(route: route, flow: presentation.flow)
        } ?? ScreenReference(rootNamed: VisibleScreen.words(presentation.flow.name), flow: presentation.flow)
        let journey = FlowJourney(
            flow: presentation.flow,
            screen: screen,
            presenter: visit?.screen,
            style: presentation.style,
            origin: Self.origin(origin),
            callSite: Self.callSite(change, origin: origin),
            trigger: change.trigger,
            duration: nil
        )
        openFlows[presentation.flow] = OpenFlow(journey: journey, start: change.time)
        return .flowStarted(journey)
    }

    /// The visit to the screen on display, when it changed and is tracked, and a duplicate
    /// warning when it came back too soon.
    private func visitScreen(_ change: JourneyChange, in root: any TreeNode) -> [JourneyEntry] {
        guard let visible = VisibleScreen(in: root), visible.isTracked, visible.key != shown?.key else {
            return []
        }
        let (transition, origin) = Self.transition(of: change.changes)
        let next = ScreenVisit(
            screen: visible.screen,
            previous: visit?.screen,
            source: visible.source,
            journey: visible.journey,
            transition: transition,
            origin: Self.origin(origin),
            callSite: transition == .appear ? nil : Self.callSite(change, origin: origin),
            trigger: change.trigger,
            step: visible.step,
            timeOnPrevious: shown.map { change.time - $0.since }
        )
        let duplicate = duplicateEntry(for: next, key: visible.key, change: change)
        let showsSource = visit?.source != next.source
        visit = next
        shown = (visible.key, change.time)
        lastSeen[DuplicateKey(visible.key)] = change.time
        return [.screenViewed(next, showsSource: showsSource)] + duplicate
    }

    /// A duplicate warning when the screen came forward again within the window.
    private func duplicateEntry(for visit: ScreenVisit, key: VisibleScreen.Key, change: JourneyChange) -> [JourneyEntry] {
        guard Self.isForward(visit.transition), let last = lastSeen[DuplicateKey(key)] else {
            return []
        }
        let interval = change.time - last
        guard interval <= change.duplicateWindow else {
            return []
        }
        return [.duplicate(visit.screen, interval: interval, callSite: visit.callSite)]
    }
}

/// What makes two visits the same screen for the duplicate warning: the flow and the route,
/// wherever in the stack.
///
/// Conformances:
/// - `Hashable`, so the tracker can look up when the screen was last seen.
private struct DuplicateKey: Hashable {
    /// The screen's flow.
    let flow: FlowID

    /// The screen's route, or `nil` for a root screen with no route.
    let route: AnyRoute?

    /// The key of a screen on display.
    init(_ key: VisibleScreen.Key) {
        self.flow = key.flow
        self.route = key.route
    }
}
