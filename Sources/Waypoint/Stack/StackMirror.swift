//
//  StackMirror.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: the mirror uses only the core, so its rules are unit tested
// on Linux too. The SwiftUI part, which turns `shown` into a `NavigationPath`, is in
// `WaypointStack.swift`.

import Observation
import WaypointCore

/// The routes a SwiftUI stack shows, kept in step with its router.
///
/// The screen follows the router, and the router hears what the user does to the screen:
///
/// - When the router's path changes, the mirror shows the new path. While a push or pop is still
///   running, it holds the change and shows the newest path when the transition ends, because
///   iOS 17 drops a path change that lands mid-push (decision 0002, section 6).
/// - When the screen shows fewer routes, the user went back: the mirror reports it to the router
///   with `rendererDidPop(toCount:)`.
/// - When the screen shows more routes, a `NavigationLink(value:)` pushed something the router
///   can't read back. The router reports `rendererMismatch`, and the screen is redrawn from the
///   router.
/// - When the mirror shows a push, it tells the router the push started, and when the push ends,
///   so a second tap on the same row while the screen slides in pushes nothing (#142).
/// - When a push ends, and when the stack appears, the mirror checks that every route it
///   shows has a destination inside this stack. A route type with none is reported once as
///   `missingDestination`, and the stack shows its missing-destination screen for it (#166).
///
/// Conformances:
/// - `Observable`, so the stack redraws when `shown` changes.
@MainActor
@Observable
final class StackMirror {
    /// How long a push or pop runs. A change that lands sooner is held until it ends.
    static let transitionDuration = Duration.milliseconds(600)

    /// The router this stack draws.
    @ObservationIgnored let router: StackRouter

    /// Whether changes that land mid-transition are held. On iOS 17 only.
    @ObservationIgnored private let holdsTransitions: Bool

    /// Tells the time and runs the end of a hold.
    @ObservationIgnored private let clock: any TransitionClock

    /// The routes on screen, above the root screen.
    ///
    /// `var` because it follows the router and the user. Only `show(_:)` and
    /// ``screenDidShow(count:)`` change it.
    private(set) var shown: [AnyRoute]

    /// Goes up by one each time the screen must be drawn again from `shown`, because it showed
    /// something the router refused.
    ///
    /// `var` because each refused change adds one. Only ``screenDidShow(count:)`` changes it.
    private(set) var redrawCount = 0

    /// When the last transition started, or `nil` before the first.
    ///
    /// `var` because each change shown starts a transition, which starts again once it is drawn.
    /// Only `show(_:)`, `restartTransitionAfterDrawing(_:)` and ``screenDidShow(count:)`` change
    /// it.
    @ObservationIgnored private var lastTransition: Duration?

    /// Whether the last transition waits for the main actor to finish drawing it. Until then it
    /// counts as running from the start.
    ///
    /// `var` because each change shown waits for its drawing. Only `show(_:)` and
    /// `restartTransitionAfterDrawing(_:)` change it.
    @ObservationIgnored private var isAwaitingDrawing = false

    /// Whether a held change waits for the running transition to end.
    ///
    /// `var` because a hold starts and ends. Only `hold(for:)` and `endHold()` change it.
    @ObservationIgnored private var isHolding = false

    /// Goes up by one with each push shown, so only the newest push reports its end.
    ///
    /// `var` because each push shown adds one. Only `reportPush(of:)` changes it.
    @ObservationIgnored private var pushCount = 0

    /// The route types whose destination a screen inside this stack registered.
    ///
    /// `var` because destinations register as screens are drawn. Only
    /// ``registerDestination(_:)`` changes it. Not observed, so registering while drawing is safe.
    @ObservationIgnored private var destinations: Set<RouteKey> = []

    /// The issue reported for each route type with no destination in this stack, kept so each
    /// type is reported once.
    ///
    /// `var` because a type is added when first found missing. Only `checkDestinations()` changes
    /// it.
    @ObservationIgnored private var reportedMissing: [RouteKey: NavigationIssue] = [:]

    /// The route types on screen with no destination in this stack, with the issue reported for
    /// each. The stack shows its missing-destination screen for these.
    ///
    /// `var` because it follows what is shown and what registers. Only `checkDestinations()`
    /// changes it.
    private(set) var missingDestinations: [RouteKey: NavigationIssue] = [:]

    /// Whether a change is waiting for the running transition to end.
    var isHoldingChange: Bool {
        isHolding
    }

    /// A mirror that shows the router's path as it is now.
    init(router: StackRouter, holdsTransitions: Bool, clock: any TransitionClock) {
        self.router = router
        self.holdsTransitions = holdsTransitions
        self.clock = clock
        self.shown = router.state.path
    }

    /// How many routes two paths share from the bottom.
    private static func sharedPrefixCount(_ first: [AnyRoute], _ second: [AnyRoute]) -> Int {
        zip(first, second).prefix { pair in
            pair.0 == pair.1
        }.count
    }

    /// Shows the router's newest path now, or when the running transition ends.
    func routerDidChange() {
        guard shown != router.state.path else {
            return
        }
        guard holdsTransitions, let wait = remainingTransition() else {
            showNewest()
            return
        }
        hold(for: wait)
    }

    /// Tells the router the stack is on screen, so the journey writes the first screen when no
    /// change has, then checks a restored path for missing destinations once the stack's screens
    /// have drawn.
    ///
    /// Called when the stack appears, never from `init`: SwiftUI makes a mirror each time it makes
    /// the stack's view value and keeps only the first, so a check started in `init` would run in a
    /// mirror that no screen registers with.
    func stackDidAppear() {
        router.rendererDidAppear()
        guard !shown.isEmpty else {
            return
        }
        scheduleDestinationCheck(after: Self.transitionDuration)
    }

    /// Notes that a screen inside this stack registered a destination for `type`. Safe while
    /// drawing: when `type` was found missing, the check runs again on the next turn.
    func registerDestination<R: Route>(_ type: R.Type) {
        let key = R.routeKey
        guard destinations.insert(key).inserted, missingDestinations[key] != nil else {
            return
        }
        scheduleDestinationCheck(after: .zero)
    }

    /// Whether this stack has no destination for `route`'s type, as last checked.
    func isMissingDestination(_ route: AnyRoute) -> Bool {
        missingDestinations[route.routeKey] != nil
    }

    /// Takes what the screen shows after the user changed it: fewer routes is a pop, reported to
    /// the router; more routes is a push the router can't read back, which is refused.
    func screenDidShow(count: Int) {
        guard count <= shown.count else {
            router.rendererDidPop(toCount: count)
            redrawCount += 1
            return
        }
        guard count < shown.count else {
            return
        }
        let kept = Array(shown.prefix(count))
        show(kept)
        router.rendererDidPop(toCount: Self.sharedPrefixCount(kept, router.state.path))
    }

    /// Shows the router's newest path.
    ///
    /// Where changes are held, a path that replaces screens, such as a link from one product to
    /// another, is shown in two steps: first back to the screens both paths share, then, when that
    /// transition ends, forward to the new ones. iOS 17 drops a replacement made in one step.
    private func showNewest() {
        let target = router.state.path
        let shared = Self.sharedPrefixCount(shown, target)
        guard holdsTransitions, shared < shown.count, shared < target.count else {
            show(target)
            return
        }
        show(Array(target.prefix(shared)))
        hold(for: Self.transitionDuration)
    }

    /// Shows `routes` and starts a transition. When `routes` adds screens, it reports the push.
    private func show(_ routes: [AnyRoute]) {
        let pushes = routes.count > shown.count
        shown = routes
        let started = clock.now
        lastTransition = started
        if holdsTransitions {
            isAwaitingDrawing = true
            restartTransitionAfterDrawing(started)
        }
        if pushes, let top = routes.last {
            reportPush(of: top)
        }
    }

    /// Starts the transition that began at `started` again once the main actor is free. Drawing new
    /// screens can block the main actor for seconds on a busy device, and iOS 17 runs the
    /// transition only after that, so a hold counted from the path change would end too soon.
    private func restartTransitionAfterDrawing(_ started: Duration) {
        clock.run(after: .zero) { [weak self] in
            guard let self, self.lastTransition == started else {
                return
            }
            self.isAwaitingDrawing = false
            self.lastTransition = self.clock.now
        }
    }

    /// Tells the router a push of `route` started, and that it ended once the transition ends,
    /// unless a newer push started meanwhile. When it ends, the routes on screen are checked for
    /// missing destinations.
    private func reportPush(of route: AnyRoute) {
        pushCount += 1
        let push = pushCount
        router.rendererDidStartPush(of: route)
        clock.run(after: Self.transitionDuration) { [weak self] in
            guard let self, self.pushCount == push else {
                return
            }
            self.router.rendererDidEndPush(of: route)
            self.checkDestinations()
        }
    }

    /// Checks the routes on screen for missing destinations after `delay`. By then SwiftUI has
    /// drawn the screens below them, which register their destinations.
    private func scheduleDestinationCheck(after delay: Duration) {
        clock.run(after: delay) { [weak self] in
            self?.checkDestinations()
        }
    }

    /// Finds the route types on screen with no destination in this stack, and reports each one
    /// the first time it is found.
    private func checkDestinations() {
        let entries = shown
            .filter { !destinations.contains($0.routeKey) }
            .map { ($0.routeKey, missingIssue(for: $0)) }
        let missing = Dictionary(entries) { first, _ in
            first
        }
        guard missing != missingDestinations else {
            return
        }
        missingDestinations = missing
    }

    /// The issue for `route`'s type, reported to the router the first time.
    private func missingIssue(for route: AnyRoute) -> NavigationIssue {
        if let issue = reportedMissing[route.routeKey] {
            return issue
        }
        let issue = router.rendererFoundNoDestination(for: route)
        reportedMissing[route.routeKey] = issue
        return issue
    }

    /// Waits for the running transition to end, then shows the newest path. One hold at a time,
    /// logged at `.debug` in `renderer`.
    private func hold(for wait: Duration) {
        guard !isHolding else {
            return
        }
        isHolding = true
        router.rendererDidHoldChange(for: wait)
        clock.run(after: wait) { [weak self] in
            self?.endHold()
        }
    }

    /// Ends a hold by showing the router's newest path, never a replay of the held ones.
    private func endHold() {
        isHolding = false
        guard shown != router.state.path else {
            return
        }
        if let wait = remainingTransition() {
            hold(for: wait)
            return
        }
        showNewest()
    }

    /// How long the running transition still runs, or `nil` when none does.
    private func remainingTransition() -> Duration? {
        guard !isAwaitingDrawing else {
            return Self.transitionDuration
        }
        guard let lastTransition else {
            return nil
        }
        let remaining = Self.transitionDuration - (clock.now - lastTransition)
        return remaining > .zero ? remaining : nil
    }
}
