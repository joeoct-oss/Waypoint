//
//  TransitionClock.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: the stack mirror and its clock use only the core and the
// standard library, so they are unit tested on Linux too.

/// Tells the stack mirror the time, and runs its work later, so tests can move time by hand.
///
/// Conformances:
/// - `AnyObject`, because the mirror keeps one clock and a test advances that same clock.
@MainActor
protocol TransitionClock: AnyObject {
    /// The time since the clock started.
    var now: Duration { get }

    /// Runs `action` on the main actor after `delay`.
    func run(after delay: Duration, _ action: @escaping @MainActor () -> Void)
}

/// The real clock: the continuous clock, and tasks that sleep.
///
/// Conformances:
/// - `TransitionClock`, so a stack mirror can use it on a device.
@MainActor
final class SystemTransitionClock: TransitionClock {
    /// When the clock was made.
    private let start = ContinuousClock.now

    /// The time since the clock was made.
    var now: Duration {
        ContinuousClock.now - start
    }

    /// Sleeps for `delay` in a task, then runs `action`.
    func run(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            action()
        }
    }
}
