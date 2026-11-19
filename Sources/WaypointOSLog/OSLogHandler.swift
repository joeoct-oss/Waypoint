//
//  OSLogHandler.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(os)
    import Foundation
    import os
    import WaypointCore

    /// Writes Waypoint's logs to Apple's unified log, and its intervals as signposts.
    ///
    /// The SwiftUI and UIKit renderers use it by default, so an app sees Waypoint's notices, errors
    /// and faults in Xcode's console and in Console.app with no setup. Each `LogCategory` is its
    /// own `Logger` category under one subsystem, built once. Each `LogInterval`, such as a
    /// `transaction` or a `push`, is an `OSSignposter` interval in Instruments.
    ///
    /// The configuration filters levels and categories before a message is built, so this handler
    /// wants every message it is asked about. Each line is written as one public string: it was
    /// already redacted by Waypoint, which shows route fields as `<private>` unless the route lists
    /// them in `Route.publicLogFields` or the configuration reveals private values.
    ///
    /// ```swift
    /// let logging = LogConfiguration.osLog(subsystem: "com.example.shop.navigation")
    /// ```
    ///
    /// Conformances:
    /// - `LogHandler`, so a router tree can write to it.
    public struct OSLogHandler: LogHandler {
        /// The app's bundle identifier plus `.waypoint`, such as `com.example.shop.waypoint`, or
        /// `waypoint` for a process with no bundle identifier.
        public static var defaultSubsystem: String {
            guard let identifier = Bundle.main.bundleIdentifier else {
                return "waypoint"
            }
            return identifier + ".waypoint"
        }

        /// The subsystem every line and signpost is written under.
        public let subsystem: String

        /// The loggers and signposters, one pair per category, and the running intervals.
        let channels: OSLogChannels

        /// A handler writing under `subsystem`. Default: ``defaultSubsystem``.
        public init(subsystem: String = OSLogHandler.defaultSubsystem) {
            self.subsystem = subsystem
            self.channels = OSLogChannels(subsystem: subsystem)
        }

        /// The unified log level of a Waypoint level: `.notice` is the log's default level, the
        /// others have the same name.
        static func osLogType(for level: LogLevel) -> OSLogType {
            switch level {
            case .debug:
                return .debug
            case .info:
                return .info
            case .notice:
                return .default
            case .error:
                return .error
            case .fault:
                return .fault
            }
        }

        /// Always `true`: the configuration already filtered the level and the category.
        public func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
            true
        }

        /// Writes the line at its level, in its category, as public strings in pieces the unified
        /// log keeps whole.
        public func log(_ message: LogMessage) {
            let logger = channels.channel(for: message.category).logger
            let type = Self.osLogType(for: message.level)
            // The unified log cuts a message at about 1 KB, so a long one, such as a journey
            // box, goes out as consecutive messages of whole lines.
            for piece in LogChunks.split(message.text) {
                logger.log(level: type, "\(piece, privacy: .public)")
            }
        }

        /// Starts a signpost interval in the interval's category.
        public func beginInterval(_ interval: LogInterval) {
            channels.begin(interval)
        }

        /// Ends the signpost interval `interval` started. An interval that never started is
        /// ignored.
        public func endInterval(_ interval: LogInterval) {
            channels.end(interval)
        }
    }

    /// The loggers and signposters of one ``OSLogHandler``, built once per category, and the state
    /// of each running interval.
    ///
    /// Conformances:
    /// - `@unchecked Sendable`, because handlers are called from any thread; every stored value
    ///   is read and written only under `lock`.
    final class OSLogChannels: @unchecked Sendable {
        /// One category's logger and signposter.
        struct Channel {
            /// Writes the category's lines.
            let logger: Logger
            /// Writes the category's signposts.
            let signposter: OSSignposter
        }

        /// The subsystem of every channel.
        let subsystem: String

        /// Guards `built` and `running`.
        private let lock = NSLock()

        /// The channels built so far, by category name. `var` because a category's channel is
        /// built the first time it is used. Only ``channel(for:)`` changes it.
        private var built: [String: Channel] = [:]

        /// The state of each running interval, to end it. `var` because intervals start and end.
        /// Only ``begin(_:)`` and ``end(_:)`` change it.
        private var running: [LogInterval: OSSignpostIntervalState] = [:]

        /// How many channels were built, one per category used.
        var builtCount: Int {
            lock.withLock {
                built.count
            }
        }

        /// How many intervals started and haven't ended.
        var runningCount: Int {
            lock.withLock {
                running.count
            }
        }

        /// Channels under `subsystem`, none built yet.
        init(subsystem: String) {
            self.subsystem = subsystem
        }

        /// The signpost name of an interval. Signpost names must be fixed strings, so the
        /// intervals Waypoint measures keep their own name, and any other is an `interval`
        /// whose message names it.
        static func signpostName(_ name: String) -> StaticString {
            switch name {
            case "transaction":
                return "transaction"
            case "push":
                return "push"
            default:
                return "interval"
            }
        }

        /// The channel of `category`, built the first time it is asked for.
        func channel(for category: LogCategory) -> Channel {
            lock.withLock {
                guard let channel = built[category.name] else {
                    return buildChannel(for: category)
                }
                return channel
            }
        }

        /// Starts the signpost interval of `interval`.
        func begin(_ interval: LogInterval) {
            let signposter = channel(for: interval.category).signposter
            let name = Self.signpostName(interval.name)
            let state = signposter.beginInterval(
                name,
                id: signposter.makeSignpostID(),
                "\(interval.name, privacy: .public)"
            )
            lock.withLock {
                running[interval] = state
            }
        }

        /// Ends the signpost interval of `interval`, if it started.
        func end(_ interval: LogInterval) {
            let state = lock.withLock {
                running.removeValue(forKey: interval)
            }
            guard let state else {
                return
            }
            let signposter = channel(for: interval.category).signposter
            signposter.endInterval(Self.signpostName(interval.name), state)
        }

        /// Builds and keeps the channel of `category`. Called under `lock`.
        private func buildChannel(for category: LogCategory) -> Channel {
            let channel = Channel(
                logger: Logger(subsystem: subsystem, category: category.name),
                signposter: OSSignposter(subsystem: subsystem, category: category.name)
            )
            built[category.name] = channel
            return channel
        }
    }
#endif
