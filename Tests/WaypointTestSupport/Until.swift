//
//  Until.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Observation

/// Returns once `condition` holds, waking each time the observable state it reads changes, as a
/// renderer does. It never sleeps or polls, so `condition` must read observable state, such as a
/// router's `state` or `presented`. When the task is cancelled, such as by a suite's time limit,
/// it returns at once, so a condition that never holds fails the test instead of hanging it.
@MainActor
package func until(_ condition: @escaping @MainActor () -> Bool) async {
    while !condition(), !Task.isCancelled {
        let wake = Wake()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                wake.set(continuation)
                withObservationTracking {
                    _ = condition()
                } onChange: {
                    wake.resume()
                }
            }
        } onCancel: {
            wake.resume()
        }
    }
}

/// Resumes one suspended `until` once, from whichever comes first: a change or a cancellation.
///
/// Conformances:
/// - `@unchecked Sendable`, because a change and a cancellation can arrive on any thread; the
///   continuation is read and cleared only under `lock`.
private final class Wake: @unchecked Sendable {
    /// Guards `continuation` and `isWoken`.
    private let lock = NSLock()

    /// The suspended call. `var` because it is set once and cleared when resumed.
    private var continuation: CheckedContinuation<Void, Never>?

    /// Whether a change or cancellation came. `var` because it is set once, maybe before the
    /// call suspends.
    private var isWoken = false

    /// Keeps the suspended call, or resumes it at once when it was already woken.
    func set(_ continuation: CheckedContinuation<Void, Never>) {
        let resumeNow = lock.withLock {
            guard !isWoken else {
                return true
            }
            self.continuation = continuation
            return false
        }
        if resumeNow {
            continuation.resume()
        }
    }

    /// Resumes the suspended call, once.
    func resume() {
        let waiting = lock.withLock {
            isWoken = true
            let waiting = self.continuation
            self.continuation = nil
            return waiting
        }
        waiting?.resume()
    }
}
