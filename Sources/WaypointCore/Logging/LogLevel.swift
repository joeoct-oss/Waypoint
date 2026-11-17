//
//  LogLevel.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How important a log message is. The five levels match Apple's unified logging one to one.
///
/// Conformances:
/// - `Int` raw value: orders the levels.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Comparable`, so levels can be compared, as in `level >= .notice`.
/// - `CustomStringConvertible`, so a level prints its name.
public enum LogLevel: Int, Sendable, Comparable, CustomStringConvertible {
    /// Details for debugging Waypoint itself, such as a queued call.
    case debug
    /// Normal changes, such as a push.
    case info
    /// Things worth keeping in release logs.
    case notice
    /// A call that failed and was recovered by its fallback.
    case error
    /// A call that failed and could not be recovered.
    case fault

    /// The case name.
    public var description: String {
        switch self {
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .notice:
            return "notice"
        case .error:
            return "error"
        case .fault:
            return "fault"
        }
    }

    /// Orders levels from `debug` to `fault`.
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
