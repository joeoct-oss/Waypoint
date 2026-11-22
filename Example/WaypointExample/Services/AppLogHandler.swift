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
nonisolated struct AppLogHandler: LogHandler {
    let system: OSLogHandler
    let systemLevel: LogLevel
    let issues: IssueLogHandler
    let events: EventLogHandler

    init(systemLevel: LogLevel, issues: IssueLog, events: EventLog) {
        system = OSLogHandler()
        self.systemLevel = systemLevel
        self.issues = IssueLogHandler(issues: issues)
        self.events = EventLogHandler(events: events)
    }

    func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        sendsToSystem(level: level, category: category)
            || issues.isEnabled(level: level, category: category)
            || events.isEnabled(level: level, category: category)
    }

    func log(_ message: LogMessage) {
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

    func beginInterval(_ interval: LogInterval) {
        system.beginInterval(interval)
    }

    func endInterval(_ interval: LogInterval) {
        system.endInterval(interval)
    }

    private func sendsToSystem(level: LogLevel, category: LogCategory) -> Bool {
        level >= systemLevel && system.isEnabled(level: level, category: category)
    }
}
