//
//  LogHandler.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// One log message, built only when its level and category are enabled.
///
/// The text already follows the privacy rules of ``LogConfiguration/revealsPrivateValues``:
/// route fields are `<private>` unless the route lists them in ``Route/publicLogFields``.
///
/// Conformances:
/// - `Sendable`, so handlers can write it from any thread.
public struct LogMessage: Sendable {
    /// How important the message is.
    public let level: LogLevel

    /// What part of Waypoint it is about.
    public let category: LogCategory

    /// The message, such as `pushed [ProductRoute(id: <private>)] flow=main`.
    public let text: String

    /// The file of the navigation call it is about.
    public let file: StaticString

    /// The line of the navigation call it is about.
    public let line: UInt

    /// Creates a message.
    public init(level: LogLevel, category: LogCategory, text: String, file: StaticString, line: UInt) {
        self.level = level
        self.category = category
        self.text = text
        self.file = file
        self.line = line
    }
}

/// A measured span of time, such as applying one transaction. On Apple platforms it becomes a
/// signpost interval in Instruments.
///
/// Conformances:
/// - `Sendable`, so handlers can receive it from any thread.
/// - `Hashable`, so handlers can match the end of an interval to its start.
public struct LogInterval: Sendable, Hashable {
    /// What is measured, such as `transaction`.
    public let name: String

    /// What part of Waypoint it is about.
    public let category: LogCategory

    /// Tells overlapping intervals with the same name apart.
    public let id: UInt64

    /// Creates an interval.
    public init(name: String, category: LogCategory, id: UInt64) {
        self.name = name
        self.category = category
        self.id = id
    }
}

/// Where log messages go.
///
/// Conformances:
/// - `Sendable`, because messages can be written from any thread.
public protocol LogHandler: Sendable {
    /// Whether messages of this level and category are wanted. Waypoint asks before it builds a
    /// message, so a disabled message costs nothing.
    func isEnabled(level: LogLevel, category: LogCategory) -> Bool

    /// Writes one message.
    func log(_ message: LogMessage)

    /// Starts a measured interval. Default: does nothing.
    func beginInterval(_ interval: LogInterval)

    /// Ends a measured interval. Default: does nothing.
    func endInterval(_ interval: LogInterval)
}

extension LogHandler {
    /// Does nothing.
    public func beginInterval(_ interval: LogInterval) { }

    /// Does nothing.
    public func endInterval(_ interval: LogInterval) { }
}

/// A handler that wants nothing, so no message is ever built.
///
/// Conformances:
/// - `LogHandler`, so it can stand in where logging is off.
public struct DisabledLogHandler: LogHandler {
    /// Creates the handler.
    public init() { }

    /// Always `false`.
    public func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        false
    }

    /// Never called, because nothing is enabled.
    public func log(_ message: LogMessage) { }
}
