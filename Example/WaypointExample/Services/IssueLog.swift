//
//  IssueLog.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import WaypointCore

// The newest navigation issue Waypoint logged at `.error` or above, such as a system link pushing
// inside a Waypoint stack. Every window's routers log to it, and the products stacks show it in a
// banner, so a reader, or a UI test, sees it in debug and release builds alike.
//
// Conformances:
// - `Observable` (from `@Observable`), so the banner appears when an issue arrives.
@MainActor
@Observable
final class IssueLog {
    // `var` because each issue logged replaces it. Only `record(_:)` changes it.
    private(set) var latest: String?

    init() {
        latest = nil
    }

    func record(_ text: String) {
        latest = text
    }
}

// Sends the `issues` category, from `.error` up, to an issue log.
//
// Conformances:
// - `LogHandler`, so the app's navigation configuration can log to it.
struct IssueLogHandler: LogHandler {
    let issues: IssueLog

    func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        category == .issues && level >= .error
    }

    func log(_ message: LogMessage) {
        let text = message.text
        Task { @MainActor in
            issues.record(text)
        }
    }
}
