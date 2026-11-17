//
//  LogConfiguration.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How a whole router tree logs. Set it once on the root router; every router in the tree uses
/// it, and there is no global logger, so parallel tests don't share one.
///
/// ```swift
/// #if DEBUG
/// router.setLogging(LogConfiguration(handler: myHandler, minimumLevel: .debug, revealsPrivateValues: true))
/// #endif
/// ```
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct LogConfiguration: Sendable {
    /// Notices, errors and faults in every category, with private values hidden.
    public static var `default`: LogConfiguration {
        LogConfiguration()
    }

    /// Nothing is logged and no message is built.
    public static var disabled: LogConfiguration {
        LogConfiguration(handler: DisabledLogHandler())
    }

    /// Where messages go.
    public let handler: any LogHandler

    /// The least important level that is written. Default: `.notice`.
    public let minimumLevel: LogLevel

    /// The categories that are written, or `nil` for all. Default: all.
    public let categories: Set<LogCategory>?

    /// Whether route field values are written as they are, instead of `<private>`. Turn it on in
    /// debug builds only. Default: `false`.
    public let revealsPrivateValues: Bool

    /// Creates a configuration. Every argument has a default; the default handler writes
    /// nothing until a renderer or the app sets one.
    public init(
        handler: any LogHandler = DisabledLogHandler(),
        minimumLevel: LogLevel = .notice,
        categories: Set<LogCategory>? = nil,
        revealsPrivateValues: Bool = false
    ) {
        self.handler = handler
        self.minimumLevel = minimumLevel
        self.categories = categories
        self.revealsPrivateValues = revealsPrivateValues
    }

    /// The same configuration, writing to another handler.
    public func withHandler(_ handler: any LogHandler) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues
        )
    }

    /// The same configuration, writing from another level up.
    public func withMinimumLevel(_ level: LogLevel) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            minimumLevel: level,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues
        )
    }

    /// The same configuration, writing other categories, or all of them for `nil`.
    public func withCategories(_ categories: Set<LogCategory>?) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues
        )
    }

    /// The same configuration, with route field values revealed or hidden.
    public func withPrivateValuesRevealed(_ reveals: Bool) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: reveals
        )
    }

    /// Whether a message of this level and category would be written.
    public func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        guard level >= minimumLevel else {
            return false
        }
        guard categories?.contains(category) ?? true else {
            return false
        }
        return handler.isEnabled(level: level, category: category)
    }

    /// Whether intervals of this category are measured: the category is written at the minimum
    /// level.
    public func measuresIntervals(in category: LogCategory) -> Bool {
        isEnabled(level: minimumLevel, category: category)
    }
}
