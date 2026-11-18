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
    /// `var` because each change shown starts a transition. Only `show(_:)` and
    /// ``screenDidShow(count:)`` change it.
    @ObservationIgnored private var lastTransition: Duration?

    /// Whether a held change waits for the running transition to end.
    ///
    /// `var` because a hold starts and ends. Only `hold(for:)` and `endHold()` change it.
    @ObservationIgnored private var isHolding = false

    /// Goes up by one with each push shown, so only the newest push reports its end.
    ///
    /// `var` because each push shown adds one. Only `reportPush(of:)` changes it.
    @ObservationIgnored private var pushCount = 0

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
        lastTransition = clock.now
        if pushes, let top = routes.last {
            reportPush(of: top)
        }
    }

    /// Tells the router a push of `route` started, and that it ended once the transition ends,
    /// unless a newer push started meanwhile.
    private func reportPush(of route: AnyRoute) {
        pushCount += 1
        let push = pushCount
        router.rendererDidStartPush(of: route)
        clock.run(after: Self.transitionDuration) { [weak self] in
            guard let self, self.pushCount == push else {
                return
            }
            self.router.rendererDidEndPush(of: route)
        }
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
        showNewest()
    }

    /// How long the running transition still runs, or `nil` when none does.
    private func remainingTransition() -> Duration? {
        guard let lastTransition else {
            return nil
        }
        let remaining = Self.transitionDuration - (clock.now - lastTransition)
        return remaining > .zero ? remaining : nil
    }
}
