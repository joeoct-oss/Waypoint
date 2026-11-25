//
//  AppLogHandler.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Waypoint

// Writes the Waypoint lines from `systemLevel` up, and every interval, to the unified log, so
// Console.app shows the lines under the `dev.waypoint.example.waypoint` subsystem and Instruments
// shows the `transaction` and `push` intervals as signposts. It also sends the lines the issue log
// wants to `issues`, so the banner keeps working, and every call's line to `events`, so the Lab's
// event log lists each call, even those below `systemLevel`.
//
// Conformances:
// - `LogHandler`, so the app's navigation configuration can log to it.
package nonisolated struct AppLogHandler: LogHandler {
    package let system: OSLogHandler
    package let systemLevel: LogLevel
    package let issues: IssueLogHandler
    package let events: EventLogHandler

    package init(systemLevel: LogLevel, issues: IssueLog, events: EventLog) {
        system = OSLogHandler()
        self.systemLevel = systemLevel
        self.issues = IssueLogHandler(issues: issues)
        self.events = EventLogHandler(events: events)
    }

    package func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        sendsToSystem(level: level, category: category)
            || issues.isEnabled(level: level, category: category)
            || events.isEnabled(level: level, category: category)
    }

    package func log(_ message: LogMessage) {
        if sendsToSystem(level: message.level, category: message.category) {
            system.log(message)
        }
        if issues.isEnabled(level: message.level, category: message.category) {
            issues.log(message)
        }
        if events.isEnabled(level: message.level, category: message.category) {
            events.log(message)
        }
    }

    package func beginInterval(_ interval: LogInterval) {
        system.beginInterval(interval)
    }

    package func endInterval(_ interval: LogInterval) {
        system.endInterval(interval)
    }

    private func sendsToSystem(level: LogLevel, category: LogCategory) -> Bool {
        level >= systemLevel && system.isEnabled(level: level, category: category)
    }
}
