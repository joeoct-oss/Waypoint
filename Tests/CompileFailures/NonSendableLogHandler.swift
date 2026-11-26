//
//  NonSendableLogHandler.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must not compile: a log handler can be called from any thread, so it must be `Sendable`.
// expected-error: stored property 'lines' of 'Sendable'-conforming class 'LineCollector' is mutable
// swift-5: warns

import WaypointCore

// Conformances:
// - `LogHandler`, which requires `Sendable`.
final class LineCollector: LogHandler {
    var lines: [String] = []

    func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        true
    }

    func log(_ message: LogMessage) {
        lines.append(message.text)
    }
}
