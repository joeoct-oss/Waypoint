//
//  RecordingLogHandler.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import WaypointCore

/// A log handler that keeps every message and interval, for tests.
///
/// Conformances:
/// - `LogHandler`, so a router can log to it.
/// - `@unchecked Sendable`, because handlers can be called from any thread; every stored value
///   is read and written only under `lock`.
package final class RecordingLogHandler: LogHandler, @unchecked Sendable {
    /// One recorded interval event.
    ///
    /// Conformances:
    /// - `Equatable`, so tests can compare events.
    /// - `Sendable`, so events can leave the lock.
    package enum IntervalEvent: Equatable, Sendable {
        case began(LogInterval)
        case ended(LogInterval)
    }

    /// Guards the recorded values.
    private let lock = NSLock()

    /// The messages, in the order they arrived.
    private var recordedMessages: [LogMessage] = []

    /// The interval events, in the order they arrived.
    private var recordedIntervals: [IntervalEvent] = []

    /// The number of times `isEnabled(level:category:)` was asked.
    private var recordedChecks = 0

    /// Whether the handler accepts messages.
    private let accepts: Bool

    /// Creates a handler that accepts every message, or none.
    package init(accepts: Bool = true) {
        self.accepts = accepts
    }

    /// The messages so far.
    package var messages: [LogMessage] {
        lock.withLock {
            recordedMessages
        }
    }

    /// The text of each message so far.
    package var texts: [String] {
        messages.map(\.text)
    }

    /// The interval events so far.
    package var intervals: [IntervalEvent] {
        lock.withLock {
            recordedIntervals
        }
    }

    /// The number of enabled checks so far.
    package var checks: Int {
        lock.withLock {
            recordedChecks
        }
    }

    /// Counts the check, then answers whether the handler accepts messages.
    package func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        lock.withLock {
            recordedChecks += 1
        }
        return accepts
    }

    /// Records the message.
    package func log(_ message: LogMessage) {
        lock.withLock {
            recordedMessages.append(message)
        }
    }

    /// Records the start of an interval.
    package func beginInterval(_ interval: LogInterval) {
        lock.withLock {
            recordedIntervals.append(.began(interval))
        }
    }

    /// Records the end of an interval.
    package func endInterval(_ interval: LogInterval) {
        lock.withLock {
            recordedIntervals.append(.ended(interval))
        }
    }
}
