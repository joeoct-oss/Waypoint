//
//  NavigationIssueLog.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import os
    import WaypointCore

    /// Where the SwiftUI renderer reports a navigation issue that has no router to report to,
    /// such as a property wrapper with no stack above its view.
    ///
    /// The issue goes to the unified log as a fault, so it shows in Xcode's console in every
    /// build. Its message names the wrapper, its file and line, and the fix, and holds no user
    /// data.
    enum NavigationIssueLog {
        /// The log the issues go to.
        static let logger = Logger(subsystem: "Waypoint", category: "issues")

        /// Logs `issue` as a fault.
        @MainActor
        static func report(_ issue: NavigationIssue) {
            logger.fault("\(issue.description, privacy: .public)\n  \(issue.message, privacy: .public)")
        }
    }
#endif
