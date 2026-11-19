//
//  LogConfiguration+OSLog.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(os)
    import WaypointCore

    extension LogConfiguration {
        /// Logging to the unified log under `subsystem`, with every other setting at its default
        /// unless given. The renderers already use the unified log when the app gives no handler,
        /// so an app needs this only to change the subsystem, or to say so explicitly.
        ///
        /// ```swift
        /// #if DEBUG
        /// let logging = LogConfiguration.osLog(minimumLevel: .debug, revealsPrivateValues: true)
        /// #else
        /// let logging = LogConfiguration.osLog()
        /// #endif
        /// ```
        ///
        /// - Parameters:
        ///   - subsystem: The subsystem lines are written under.
        ///     Default: ``OSLogHandler/defaultSubsystem``.
        ///   - minimumLevel: The least important level written. Default: `.notice`.
        ///   - revealsPrivateValues: Whether route field values are written as they are. Turn it
        ///     on in debug builds only. Default: `false`.
        public static func osLog(
            subsystem: String = OSLogHandler.defaultSubsystem,
            minimumLevel: LogLevel = .notice,
            revealsPrivateValues: Bool = false
        ) -> LogConfiguration {
            LogConfiguration(
                handler: OSLogHandler(subsystem: subsystem),
                minimumLevel: minimumLevel,
                revealsPrivateValues: revealsPrivateValues
            )
        }
    }
#endif
