//
//  RecordingLogHandler.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
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

    /// The messages, in the order they arrived. `var` because the router logs one at a time.
    private var recordedMessages: [LogMessage] = []

    /// The interval events, in the order they arrived. `var` because intervals arrive one at a
    /// time.
    private var recordedIntervals: [IntervalEvent] = []

    /// The number of times `isEnabled(level:category:)` was asked. `var` because each check adds
    /// one.
    private var recordedChecks = 0

    /// How the journey's lines start, in the readable format with and without symbols and in the
    /// structured format.
    private static let journeyStarts = [
        "🧭 ",
        "⚠️ ",
        "┌─ 🧭",
        "+- Waypoint",
        "Waypoint screen_viewed",
        "Waypoint tab_selected",
        "Waypoint flow_",
        "Waypoint duplicate",
        "screen_viewed ",
        "tab_selected ",
        "flow_started ",
        "flow_finished ",
        "flow_cancelled ",
        "duplicate_screen ",
    ]

    /// Whether the handler accepts messages.
    private let accepts: Bool

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

    /// The messages so far that the routers write about their own mechanics and issues, without
    /// the journey's lines and boxes.
    package var routerMessages: [LogMessage] {
        messages.filter { message in
            !Self.isJourney(message.text)
        }
    }

    /// The text of each router message so far, without the journey's.
    package var routerTexts: [String] {
        routerMessages.map(\.text)
    }

    /// The text of each journey line so far, without the debug boxes.
    package var journeyTexts: [String] {
        texts.filter { text in
            Self.isJourney(text) && !Self.isJourneyBox(text)
        }
    }

    /// The journey's debug boxes so far.
    package var journeyBoxes: [String] {
        texts.filter(Self.isJourneyBox)
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

    /// Creates a handler that accepts every message, or none.
    package init(accepts: Bool = true) {
        self.accepts = accepts
    }

    /// Whether a message is one of the journey's lines or boxes.
    private static func isJourney(_ text: String) -> Bool {
        journeyStarts.contains { start in
            text.hasPrefix(start)
        }
    }

    /// Whether a message is a journey debug box.
    private static func isJourneyBox(_ text: String) -> Bool {
        text.hasPrefix("┌─ 🧭") || text.hasPrefix("+- Waypoint")
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

    /// Forgets everything recorded so far, so a test can set up a tree first and then check only
    /// what its own calls logged.
    package func removeAll() {
        lock.withLock {
            recordedMessages.removeAll()
            recordedIntervals.removeAll()
            recordedChecks = 0
        }
    }
}
