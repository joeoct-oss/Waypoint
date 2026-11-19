//
//  AppLogHandler.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Waypoint
import WaypointCore

// Writes every Waypoint line and interval to the unified log, so Console.app shows the lines under
// the `dev.waypoint.example.waypoint` subsystem and Instruments shows the `transaction` and `push`
// intervals as signposts. It also sends the lines the issue log wants to `issues`, so the banner
// keeps working.
//
// Conformances:
// - `LogHandler`, so the app's navigation configuration can log to it.
struct AppLogHandler: LogHandler {
    let system: OSLogHandler
    let issues: IssueLogHandler

    init(issues: IssueLog) {
        system = OSLogHandler()
        self.issues = IssueLogHandler(issues: issues)
    }

    func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        system.isEnabled(level: level, category: category)
            || issues.isEnabled(level: level, category: category)
    }

    func log(_ message: LogMessage) {
        system.log(message)
        if issues.isEnabled(level: message.level, category: message.category) {
            issues.log(message)
        }
    }

    func beginInterval(_ interval: LogInterval) {
        system.beginInterval(interval)
    }

    func endInterval(_ interval: LogInterval) {
        system.endInterval(interval)
    }
}
