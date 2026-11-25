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
// inside a Waypoint stack, or a call a fallback recovered. Every window's routers log to it, and
// every tab shows it in a banner, so a reader, or a UI test, sees it in debug and release builds
// alike. It also counts the calls no fallback recovered.
//
// Conformances:
// - `Observable` (from `@Observable`), so the banner appears when an issue arrives.
@Observable
package final class IssueLog {
    // `var` because each issue logged replaces it. Only `record(_:)` changes it.
    package private(set) var latest: String?
    // `var` because the configuration's `onNavigationFailure` counts each call no fallback
    // recovered. Only `recordFailure(_:)` changes it.
    package private(set) var failureCount: Int

    package init() {
        latest = nil
        failureCount = 0
    }

    package func record(_ text: String) {
        latest = text
    }

    package func recordFailure(_ failure: NavigationFailure) {
        failureCount += 1
    }
}

// Sends the `issues` category, from `.error` up, to an issue log.
//
// Conformances:
// - `LogHandler`, so the app's navigation configuration can log to it.
package nonisolated struct IssueLogHandler: LogHandler {
    package let issues: IssueLog

    package func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        category == .issues && level >= .error
    }

    package func log(_ message: LogMessage) {
        let text = message.text
        Task { @MainActor in
            issues.record(text)
        }
    }
}
